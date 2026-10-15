/// Test doubles for a kit's own tests (spec 3a C1.11): [FakePlanServices],
/// a `PlanServices` over a document, so a kit's tools, grips and providers
/// are tested without the plan library. It moves with the contract: a
/// member the contract adds to `PlanServices` is added here in the same
/// change, so a kit's tests keep compiling.
library;

export 'src/testing/fake_plan_services.dart';
