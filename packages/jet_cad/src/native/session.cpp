#include "session.hpp"

#include <memory>

#include <BRepAlgoAPI_BooleanOperation.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

namespace jetcad {

namespace {

// Finds the id assigned to `shape` in a freshly registered body, or "".
std::string idOfShape(const Body& body, TopAbs_ShapeEnum kind,
                      const TopoDS_Shape& shape) {
  const auto& list = kind == TopAbs_FACE   ? body.faces
                     : kind == TopAbs_EDGE ? body.edges
                                           : body.vertices;
  for (const auto& [id, s] : list) {
    if (s.IsSame(shape)) return id;
  }
  return {};
}

}  // namespace

std::string Session::nextId(const char* prefix) {
  return std::string(prefix) + std::to_string(++counter_);
}

Body& Session::requireBody(const std::string& id) {
  auto it = bodies_.find(id);
  if (it == bodies_.end()) throw CommandError("unknown body: " + id);
  return it->second;
}

const TopoDS_Shape& Session::requireSubshape(TopAbs_ShapeEnum kind,
                                             const std::string& id) const {
  for (const auto& [bodyId, body] : bodies_) {
    const auto& list = kind == TopAbs_FACE   ? body.faces
                       : kind == TopAbs_EDGE ? body.edges
                                             : body.vertices;
    for (const auto& [subId, shape] : list) {
      if (subId == id) return shape;
    }
  }
  throw CommandError("unknown subshape: " + id);
}

std::string Session::bodyIdOwningSubshape(TopAbs_ShapeEnum kind,
                                          const std::string& id) const {
  for (const auto& [bodyId, body] : bodies_) {
    const auto& list = kind == TopAbs_FACE   ? body.faces
                       : kind == TopAbs_EDGE ? body.edges
                                             : body.vertices;
    for (const auto& [subId, shape] : list) {
      if (subId == id) return bodyId;
    }
  }
  throw CommandError("unknown subshape: " + id);
}

std::vector<TopoDS_Shape> Session::enumerate(const TopoDS_Shape& shape,
                                             TopAbs_ShapeEnum kind) {
  TopTools_IndexedMapOfShape map;
  TopExp::MapShapes(shape, kind, map);
  std::vector<TopoDS_Shape> out;
  out.reserve(map.Extent());
  for (int i = 1; i <= map.Extent(); ++i) out.push_back(map(i));
  return out;
}

json Session::registerBody(const TopoDS_Shape& shape) {
  Body body;
  body.shape = shape;
  json faces = json::array(), edges = json::array(),
       vertices = json::array();
  for (const auto& f : enumerate(shape, TopAbs_FACE)) {
    auto id = nextId("f");
    body.faces.emplace_back(id, f);
    faces.push_back(id);
  }
  for (const auto& e : enumerate(shape, TopAbs_EDGE)) {
    auto id = nextId("e");
    body.edges.emplace_back(id, e);
    edges.push_back(id);
  }
  for (const auto& v : enumerate(shape, TopAbs_VERTEX)) {
    auto id = nextId("v");
    body.vertices.emplace_back(id, v);
    vertices.push_back(id);
  }
  auto bodyId = nextId("b");
  bodies_.emplace(bodyId, std::move(body));
  return json{{"body", bodyId},
              {"faces", faces},
              {"edges", edges},
              {"vertices", vertices},
              {"remap", json::object()}};
}

json Session::makeBox(const json& cmd) {
  const auto& size = cmd.at("size");
  double dx = size.at(0), dy = size.at(1), dz = size.at(2);
  if (dx <= 0 || dy <= 0 || dz <= 0) {
    throw CommandError("box dimensions must be positive");
  }
  BRepPrimAPI_MakeBox make(dx, dy, dz);
  return registerBody(make.Shape());
}

json Session::deleteBodies(const json& cmd) {
  // Idempotent by contract: unknown ids are silently ignored (undo paths
  // may delete already-gone bodies).
  for (const auto& id : cmd.at("bodies")) {
    bodies_.erase(id.get<std::string>());
  }
  return json::object();
}

json Session::execute(const json& cmd) {
  const std::string name = cmd.at("cmd").get<std::string>();
  if (name == "makeBox") return makeBox(cmd);
  if (name == "extrude") return extrude(cmd);
  if (name == "boolean") return booleanOp(cmd);
  if (name == "fillet") return fillet(cmd);
  if (name == "transform") return transform(cmd);
  if (name == "importStep") return importStep(cmd);
  if (name == "exportStep") return exportStep(cmd);
  if (name == "snapshotBodies") return snapshotBodies(cmd);
  if (name == "restoreBodies") return restoreBodies(cmd);
  if (name == "deleteBodies") return deleteBodies(cmd);
  if (name == "saveSnapshot") return saveSnapshot(cmd);
  if (name == "restoreSession") return restoreSession(cmd);
  throw CommandError("unknown command: " + name);
}

json Session::booleanOp(const json& cmd) {
  const std::string aId = cmd.at("a"), bId = cmd.at("b");
  if (aId == bId) throw CommandError("boolean operands must be distinct");
  Body a = requireBody(aId);  // copies: we erase before registering result
  Body b = requireBody(bId);
  const std::string op = cmd.at("op");

  std::unique_ptr<BRepAlgoAPI_BooleanOperation> algo;
  if (op == "fuse") {
    algo = std::make_unique<BRepAlgoAPI_Fuse>(a.shape, b.shape);
  } else if (op == "cut") {
    algo = std::make_unique<BRepAlgoAPI_Cut>(a.shape, b.shape);
  } else if (op == "common") {
    algo = std::make_unique<BRepAlgoAPI_Common>(a.shape, b.shape);
  } else {
    throw CommandError("unknown boolean op: " + op);
  }
  if (!algo->IsDone()) throw CommandError("boolean operation failed");
  TopoDS_Shape result = algo->Shape();
  if (result.IsNull()) throw CommandError("boolean produced empty result");

  bodies_.erase(aId);
  bodies_.erase(bId);
  json out = registerBody(result);
  const Body& newBody = bodies_.at(out.at("body").get<std::string>());

  json remap = json::object();
  remap[aId] = json::array({out.at("body")});
  remap[bId] = json::array({out.at("body")});
  auto mapOld = [&](TopAbs_ShapeEnum kind,
                    const std::vector<std::pair<std::string, TopoDS_Shape>>&
                        olds) {
    for (const auto& [oldId, oldShape] : olds) {
      json targets = json::array();
      if (!algo->IsDeleted(oldShape)) {
        const auto& mods = algo->Modified(oldShape);
        if (!mods.IsEmpty()) {
          for (const auto& m : mods) {
            auto id = idOfShape(newBody, kind, m);
            if (!id.empty()) targets.push_back(id);
          }
        } else {
          // Survived unmodified: geometry identical, but ids are fresh in
          // v1 (boolean consumes inputs wholesale). Map to the new id.
          auto id = idOfShape(newBody, kind, oldShape);
          if (!id.empty()) targets.push_back(id);
        }
      }
      remap[oldId] = targets;
    }
  };
  for (const Body* src : {&a, &b}) {
    mapOld(TopAbs_FACE, src->faces);
    mapOld(TopAbs_EDGE, src->edges);
    mapOld(TopAbs_VERTEX, src->vertices);
  }
  out["remap"] = remap;
  return out;
}

// Stubs replaced by Tasks 5-6; keep the linker happy and honest.
json Session::extrude(const json&) { throw CommandError("not implemented: extrude"); }
json Session::fillet(const json&) { throw CommandError("not implemented: fillet"); }
json Session::transform(const json&) { throw CommandError("not implemented: transform"); }
json Session::importStep(const json&) { throw CommandError("not implemented: importStep"); }
json Session::exportStep(const json&) { throw CommandError("not implemented: exportStep"); }
json Session::snapshotBodies(const json&) { throw CommandError("not implemented: snapshotBodies"); }
json Session::restoreBodies(const json&) { throw CommandError("not implemented: restoreBodies"); }
json Session::saveSnapshot(const json&) { throw CommandError("not implemented: saveSnapshot"); }
json Session::restoreSession(const json&) { throw CommandError("not implemented: restoreSession"); }

}  // namespace jetcad
