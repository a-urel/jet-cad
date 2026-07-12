#include "session.hpp"

#include <BRepPrimAPI_MakeBox.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

namespace jetcad {

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

// Stubs replaced by Tasks 4-6; keep the linker happy and honest.
json Session::extrude(const json&) { throw CommandError("not implemented: extrude"); }
json Session::booleanOp(const json&) { throw CommandError("not implemented: boolean"); }
json Session::fillet(const json&) { throw CommandError("not implemented: fillet"); }
json Session::transform(const json&) { throw CommandError("not implemented: transform"); }
json Session::importStep(const json&) { throw CommandError("not implemented: importStep"); }
json Session::exportStep(const json&) { throw CommandError("not implemented: exportStep"); }
json Session::snapshotBodies(const json&) { throw CommandError("not implemented: snapshotBodies"); }
json Session::restoreBodies(const json&) { throw CommandError("not implemented: restoreBodies"); }
json Session::saveSnapshot(const json&) { throw CommandError("not implemented: saveSnapshot"); }
json Session::restoreSession(const json&) { throw CommandError("not implemented: restoreSession"); }

}  // namespace jetcad
