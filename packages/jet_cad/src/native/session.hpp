#pragma once

#include <cstdint>
#include <map>
#include <string>
#include <vector>

#include <TopAbs_ShapeEnum.hxx>
#include <TopoDS_Shape.hxx>
#include <nlohmann/json.hpp>

namespace jetcad {

using json = nlohmann::json;

// Thrown for invalid input / failed operations; becomes the error envelope.
struct CommandError : std::runtime_error {
  using std::runtime_error::runtime_error;
};

struct Body {
  TopoDS_Shape shape;
  // Insertion-ordered id -> subshape. Order matches TopExp::MapShapes.
  std::vector<std::pair<std::string, TopoDS_Shape>> faces, edges, vertices;
};

class Session {
 public:
  json execute(const json& cmd);

 private:
  json makeBox(const json&);
  json extrude(const json&);       // Task 5
  json booleanOp(const json&);     // Task 4
  json fillet(const json&);        // Task 5
  json transform(const json&);     // Task 5
  json importStep(const json&);    // Task 6
  json exportStep(const json&);    // Task 6
  json snapshotBodies(const json&);   // Task 6
  json restoreBodies(const json&);    // Task 6
  json deleteBodies(const json&);
  json saveSnapshot(const json&);     // Task 6
  json restoreSession(const json&);   // Task 6

  std::string nextId(const char* prefix);
  Body& requireBody(const std::string& id);
  std::string bodyIdOwningSubshape(TopAbs_ShapeEnum kind,
                                   const std::string& id) const;
  const TopoDS_Shape& requireSubshape(TopAbs_ShapeEnum kind,
                                      const std::string& id) const;
  // Enumerates shape's subshapes of one kind in TopExp::MapShapes order.
  static std::vector<TopoDS_Shape> enumerate(const TopoDS_Shape& shape,
                                             TopAbs_ShapeEnum kind);
  // Assigns fresh ids to every subshape and stores the body; returns result
  // json {body, faces, edges, vertices, remap:{}}.
  json registerBody(const TopoDS_Shape& shape);

  // Fully-parsed snapshotBodies payload plus the max numeric id suffix
  // seen across every body/subshape id in it.
  struct ParsedBodies {
    std::map<std::string, Body> bodies;
    uint64_t maxId = 0;
  };
  // Parses a snapshotBodies dump into a complete ParsedBodies WITHOUT
  // touching session state; throws CommandError on any malformed entry.
  // Restore paths must merge/swap only after the whole payload has parsed
  // so a corrupt payload leaves the session untouched (all-or-nothing).
  static ParsedBodies parseBodiesDump(const json& dump);

  uint64_t counter_ = 0;
  std::map<std::string, Body> bodies_;
};

}  // namespace jetcad
