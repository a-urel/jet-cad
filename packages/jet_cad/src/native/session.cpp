#include "session.hpp"

#include <atomic>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <memory>
#include <set>
#include <sstream>

#include <unistd.h>  // POSIX getpid; on Windows use _getpid from <process.h> (Plan 5 concern).

#include <BRepAdaptor_Surface.hxx>
#include <BRepAlgoAPI_BooleanOperation.hxx>
#include <BRepAlgoAPI_Common.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <BRepTools.hxx>
#include <BRep_Builder.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_StepModelType.hxx>
#include <STEPControl_Writer.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <gp_Trsf.hxx>
#include <gp_Vec.hxx>

#include "b64.hpp"

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

std::string brepToString(const TopoDS_Shape& shape) {
  std::ostringstream out;
  BRepTools::Write(shape, out);
  return out.str();
}

TopoDS_Shape brepFromString(const std::string& data) {
  std::istringstream in(data);
  TopoDS_Shape shape;
  BRep_Builder builder;
  BRepTools::Read(shape, in, builder);
  if (shape.IsNull()) throw CommandError("corrupt BREP payload");
  return shape;
}

// Unique temp path; STEP translators are file-based across OCCT versions.
std::filesystem::path tempStepPath() {
  static std::atomic<uint64_t> counter{0};
  auto name = "jet_cad_" + std::to_string(::getpid()) + "_" +
              std::to_string(++counter) + ".step";
  return std::filesystem::temp_directory_path() / name;
}

struct TempFileGuard {
  std::filesystem::path path;
  ~TempFileGuard() {
    std::error_code ec;
    std::filesystem::remove(path, ec);
  }
};

// Bumps the id counter past any numeric suffix in restored ids so a
// restored snapshot never collides with future fresh ids.
uint64_t maxNumericSuffix(const nlohmann::json& ids) {
  uint64_t maxSeen = 0;
  for (const auto& idJson : ids) {
    const std::string id = idJson.get<std::string>();
    size_t digits = id.find_first_of("0123456789");
    if (digits != std::string::npos) {
      try {
        maxSeen = std::max(maxSeen,
                           (uint64_t)std::stoull(id.substr(digits)));
      } catch (const std::exception&) {
        // std::out_of_range for absurdly long digit runs; the substring
        // starts with a digit so invalid_argument cannot happen.
        throw CommandError("corrupt snapshot: bad id");
      }
    }
  }
  return maxSeen;
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

json Session::extrude(const json& cmd) {
  const std::string faceId = cmd.at("face");
  double depth = cmd.at("depth");
  if (depth == 0) throw CommandError("extrude depth must be non-zero");
  const TopoDS_Shape& faceShape = requireSubshape(TopAbs_FACE, faceId);
  TopoDS_Face face = TopoDS::Face(faceShape);

  BRepAdaptor_Surface surf(face);
  double u = (surf.FirstUParameter() + surf.LastUParameter()) / 2.0;
  double v = (surf.FirstVParameter() + surf.LastVParameter()) / 2.0;
  gp_Pnt p;
  gp_Vec d1u, d1v;
  surf.D1(u, v, p, d1u, d1v);
  gp_Vec normal = d1u.Crossed(d1v);
  if (normal.Magnitude() < 1e-12) {
    throw CommandError("cannot compute face normal");
  }
  if (face.Orientation() == TopAbs_REVERSED) normal.Reverse();
  normal.Normalize();
  normal.Multiply(depth);

  BRepPrimAPI_MakePrism prism(face, normal);
  if (!prism.IsDone()) throw CommandError("extrude failed");
  return registerBody(prism.Shape());
}

json Session::fillet(const json& cmd) {
  const auto& edgeIds = cmd.at("edges");
  double radius = cmd.at("radius");
  if (edgeIds.empty()) throw CommandError("fillet needs at least one edge");
  if (radius <= 0) throw CommandError("fillet radius must be positive");

  const std::string bodyId =
      bodyIdOwningSubshape(TopAbs_EDGE, edgeIds[0].get<std::string>());
  for (const auto& e : edgeIds) {
    if (bodyIdOwningSubshape(TopAbs_EDGE, e.get<std::string>()) != bodyId) {
      throw CommandError("fillet edges must belong to a single body");
    }
  }
  Body old = bodies_.at(bodyId);  // copy for lineage lookup

  BRepFilletAPI_MakeFillet make(old.shape);
  std::vector<std::pair<std::string, TopoDS_Shape>> filleted;
  for (const auto& e : edgeIds) {
    const std::string id = e.get<std::string>();
    for (const auto& [subId, shape] : old.edges) {
      if (subId == id) {
        make.Add(radius, TopoDS::Edge(shape));
        filleted.emplace_back(subId, shape);
      }
    }
  }
  make.Build();
  if (!make.IsDone()) throw CommandError("fillet failed (radius too large?)");
  TopoDS_Shape newShape = make.Shape();

  // Rebuild the body under the SAME id, carrying ids forward:
  // - subshape survives (IsSame) or is Modified(old)  -> keeps old id
  // - otherwise                                       -> fresh id (reported)
  Body rebuilt;
  rebuilt.shape = newShape;
  json newFaces = json::array(), newEdges = json::array(),
       newVertices = json::array();
  auto carry = [&](TopAbs_ShapeEnum kind,
                   const std::vector<std::pair<std::string, TopoDS_Shape>>&
                       olds,
                   std::vector<std::pair<std::string, TopoDS_Shape>>& dest,
                   json& reportNew, const char* prefix) {
    // Modified(old) may map ONE old subshape to SEVERAL new ones (a face
    // split by the fillet). Only the first match keeps the old id; the
    // rest get fresh ids, or lookups by id would hit the wrong shape.
    std::set<std::string> consumed;
    for (const auto& shape : enumerate(newShape, kind)) {
      std::string carried;
      for (const auto& [oldId, oldShape] : olds) {
        if (consumed.count(oldId)) continue;
        if (shape.IsSame(oldShape)) { carried = oldId; break; }
        const auto& mods = make.Modified(oldShape);
        for (const auto& m : mods) {
          if (shape.IsSame(m)) { carried = oldId; break; }
        }
        if (!carried.empty()) break;
      }
      if (carried.empty()) {
        carried = nextId(prefix);
        reportNew.push_back(carried);
      } else {
        consumed.insert(carried);
      }
      dest.emplace_back(carried, shape);
    }
  };
  carry(TopAbs_FACE, old.faces, rebuilt.faces, newFaces, "f");
  carry(TopAbs_EDGE, old.edges, rebuilt.edges, newEdges, "e");
  carry(TopAbs_VERTEX, old.vertices, rebuilt.vertices, newVertices, "v");

  // Remap: filleted edges -> the faces Generated from them; every other
  // old subshape that no longer exists -> [].
  json remap = json::object();
  auto stillPresent = [&](TopAbs_ShapeEnum kind, const std::string& id) {
    const auto& list = kind == TopAbs_FACE   ? rebuilt.faces
                       : kind == TopAbs_EDGE ? rebuilt.edges
                                             : rebuilt.vertices;
    for (const auto& [subId, s] : list) {
      if (subId == id) return true;
    }
    return false;
  };
  for (const auto& [edgeId, edgeShape] : filleted) {
    json targets = json::array();
    const auto& generated = make.Generated(edgeShape);
    for (const auto& g : generated) {
      auto id = idOfShape(rebuilt, TopAbs_FACE, g);
      if (!id.empty()) targets.push_back(id);
    }
    remap[edgeId] = targets;
  }
  auto dropVanished = [&](TopAbs_ShapeEnum kind,
                          const std::vector<
                              std::pair<std::string, TopoDS_Shape>>& olds) {
    for (const auto& [oldId, s] : olds) {
      if (!stillPresent(kind, oldId) && !remap.contains(oldId)) {
        remap[oldId] = json::array();
      }
    }
  };
  dropVanished(TopAbs_FACE, old.faces);
  dropVanished(TopAbs_EDGE, old.edges);
  dropVanished(TopAbs_VERTEX, old.vertices);

  bodies_[bodyId] = std::move(rebuilt);
  return json{{"body", bodyId},
              {"faces", newFaces},
              {"edges", newEdges},
              {"vertices", newVertices},
              {"remap", remap}};
}

json Session::transform(const json& cmd) {
  const auto& m = cmd.at("matrix");
  if (m.size() != 16) throw CommandError("matrix must have 16 values");
  // Rigidity check on the RAW column-major 3x3 linear part, BEFORE
  // gp_Trsf::SetValues. SetValues only rejects singular input and silently
  // orthogonalizes everything else (OCCT 7.9.3, measured); checking
  // ScaleFactor() afterwards is insufficient because shear and
  // volume-preserving anisotropic scale (e.g. diag(4,0.5,0.5)) keep
  // det = 1 and come out with ScaleFactor() == 1, their distortion
  // silently discarded. Rigid <=> columns orthonormal and det > 0
  // (reflections rejected). Tolerance 1e-6: loose enough for rigid
  // matrices that round-tripped through float32 upstream, tight enough
  // to reject real distortion.
  {
    auto mv = [&](int i) { return m[i].get<double>(); };
    const double c[3][3] = {
        {mv(0), mv(1), mv(2)},   // column 0
        {mv(4), mv(5), mv(6)},   // column 1
        {mv(8), mv(9), mv(10)},  // column 2
    };
    auto dot = [&](int i, int j) {
      return c[i][0] * c[j][0] + c[i][1] * c[j][1] + c[i][2] * c[j][2];
    };
    constexpr double kTol = 1e-6;
    bool rigid = true;
    for (int i = 0; i < 3 && rigid; ++i) {
      if (std::abs(dot(i, i) - 1.0) > kTol) rigid = false;
      for (int j = i + 1; j < 3 && rigid; ++j) {
        if (std::abs(dot(i, j)) > kTol) rigid = false;
      }
    }
    // det with the columns laid out as rows equals det of the linear part
    // (det A == det A^T); > 0 for proper rotations, < 0 for reflections.
    const double det =
        c[0][0] * (c[1][1] * c[2][2] - c[1][2] * c[2][1]) -
        c[0][1] * (c[1][0] * c[2][2] - c[1][2] * c[2][0]) +
        c[0][2] * (c[1][0] * c[2][1] - c[1][1] * c[2][0]);
    if (!rigid || det <= 0) {
      throw CommandError(
          "transform must be rigid (rotation+translation); "
          "scaling/shear/reflection unsupported in v1");
    }
  }
  gp_Trsf trsf;
  try {
    // Column-major input -> gp_Trsf row-major 3x4.
    trsf.SetValues(m[0], m[4], m[8], m[12],
                   m[1], m[5], m[9], m[13],
                   m[2], m[6], m[10], m[14]);
  } catch (const Standard_Failure&) {
    // Unreachable after the orthonormality check (det ~ 1); kept as a
    // defensive belt around OCCT.
    throw CommandError(
        "transform must be rigid (rotation+translation); "
        "scaling/shear/reflection unsupported in v1");
  }
  for (const auto& idJson : cmd.at("bodies")) {
    requireBody(idJson.get<std::string>());
  }
  for (const auto& idJson : cmd.at("bodies")) {
    Body& body = bodies_.at(idJson.get<std::string>());
    Body moved;
    BRepBuilderAPI_Transform mover(body.shape, trsf, /*Copy=*/false);
    moved.shape = mover.Shape();
    // Same TShape tree, same enumeration order: transfer ids positionally.
    auto transfer = [&](TopAbs_ShapeEnum kind,
                        const std::vector<
                            std::pair<std::string, TopoDS_Shape>>& olds,
                        std::vector<std::pair<std::string, TopoDS_Shape>>&
                            dest) {
      auto shapes = enumerate(moved.shape, kind);
      if (shapes.size() != olds.size()) {
        throw CommandError("internal: transform changed topology");
      }
      for (size_t i = 0; i < shapes.size(); ++i) {
        dest.emplace_back(olds[i].first, shapes[i]);
      }
    };
    transfer(TopAbs_FACE, body.faces, moved.faces);
    transfer(TopAbs_EDGE, body.edges, moved.edges);
    transfer(TopAbs_VERTEX, body.vertices, moved.vertices);
    body = std::move(moved);
  }
  return json::object();
}

json Session::snapshotBodies(const json& cmd) {
  json dump = json::array();
  for (const auto& idJson : cmd.at("bodies")) {
    const std::string id = idJson.get<std::string>();
    const Body& body = requireBody(id);
    json entry = {{"id", id}, {"brepB64", b64encode(brepToString(body.shape))}};
    for (auto [key, list] : {std::pair{"faces", &body.faces},
                             {"edges", &body.edges},
                             {"vertices", &body.vertices}}) {
      json ids = json::array();
      for (const auto& [subId, s] : *list) ids.push_back(subId);
      entry[key] = ids;
    }
    dump.push_back(entry);
  }
  return json{{"dataB64", b64encode(dump.dump())}};
}

Session::ParsedBodies Session::parseBodiesDump(const json& dump) {
  ParsedBodies parsed;
  for (const auto& entry : dump) {
    Body body;
    body.shape = brepFromString(b64decode(entry.at("brepB64")));
    auto zip = [&](const char* key, TopAbs_ShapeEnum kind,
                   std::vector<std::pair<std::string, TopoDS_Shape>>& dest) {
      auto shapes = enumerate(body.shape, kind);
      const auto& ids = entry.at(key);
      if (ids.size() != shapes.size()) {
        throw CommandError("snapshot id/topology mismatch");
      }
      for (size_t i = 0; i < shapes.size(); ++i) {
        dest.emplace_back(ids[i].get<std::string>(), shapes[i]);
      }
      parsed.maxId = std::max(parsed.maxId, maxNumericSuffix(ids));
    };
    zip("faces", TopAbs_FACE, body.faces);
    zip("edges", TopAbs_EDGE, body.edges);
    zip("vertices", TopAbs_VERTEX, body.vertices);
    const std::string id = entry.at("id");
    parsed.maxId =
        std::max(parsed.maxId, maxNumericSuffix(json::array({id})));
    parsed.bodies[id] = std::move(body);
  }
  return parsed;
}

json Session::restoreBodies(const json& cmd) {
  auto dump = json::parse(b64decode(cmd.at("dataB64").get<std::string>()));
  // Parse the entire payload before touching session state: a corrupt
  // entry must leave the session exactly as it was (all-or-nothing).
  ParsedBodies parsed = parseBodiesDump(dump);
  for (auto& [id, body] : parsed.bodies) {
    bodies_[id] = std::move(body);
  }
  counter_ = std::max(counter_, parsed.maxId);
  return json::object();
}

json Session::saveSnapshot(const json&) {
  json allIds = json::array();
  for (const auto& [id, body] : bodies_) allIds.push_back(id);
  json bodiesDump =
      json::parse(b64decode(snapshotBodies({{"cmd", "snapshotBodies"},
                                            {"bodies", allIds}})
                                .at("dataB64")
                                .get<std::string>()));
  return json{{"dataB64",
               b64encode(json{{"counter", counter_},
                              {"bodies", bodiesDump}}
                             .dump())}};
}

json Session::restoreSession(const json& cmd) {
  auto snapshot =
      json::parse(b64decode(cmd.at("dataB64").get<std::string>()));
  // Parse everything (bodies AND counter) before mutating: a corrupt
  // payload must not clear the session (all-or-nothing; the document-load
  // path depends on this). Swap-in replaces clear-then-fill.
  ParsedBodies parsed = parseBodiesDump(snapshot.at("bodies"));
  const uint64_t saved = snapshot.at("counter").get<uint64_t>();
  bodies_ = std::move(parsed.bodies);
  counter_ = std::max(counter_, std::max(parsed.maxId, saved));
  return json::object();
}

json Session::importStep(const json& cmd) {
  const std::string bytes = b64decode(cmd.at("dataB64").get<std::string>());
  if (bytes.empty()) throw CommandError("empty STEP payload");
  TempFileGuard tmp{tempStepPath()};
  {
    std::ofstream out(tmp.path, std::ios::binary);
    out.write(bytes.data(), (std::streamsize)bytes.size());
  }
  STEPControl_Reader reader;
  if (reader.ReadFile(tmp.path.string().c_str()) != IFSelect_RetDone) {
    throw CommandError("STEP parse failed");
  }
  reader.TransferRoots();
  json results = json::array();
  for (int i = 1; i <= reader.NbShapes(); ++i) {
    TopoDS_Shape shape = reader.Shape(i);
    if (!shape.IsNull()) results.push_back(registerBody(shape));
  }
  if (results.empty()) throw CommandError("STEP contained no shapes");
  return json{{"bodies", results}};
}

json Session::exportStep(const json& cmd) {
  TopoDS_Compound compound;
  BRep_Builder builder;
  builder.MakeCompound(compound);
  for (const auto& idJson : cmd.at("bodies")) {
    builder.Add(compound, requireBody(idJson.get<std::string>()).shape);
  }
  TempFileGuard tmp{tempStepPath()};
  STEPControl_Writer writer;
  writer.Transfer(compound, STEPControl_AsIs);
  if (writer.Write(tmp.path.string().c_str()) != IFSelect_RetDone) {
    throw CommandError("STEP write failed");
  }
  std::ifstream in(tmp.path, std::ios::binary);
  std::string bytes((std::istreambuf_iterator<char>(in)),
                    std::istreambuf_iterator<char>());
  return json{{"dataB64", b64encode(bytes)}};
}

}  // namespace jetcad
