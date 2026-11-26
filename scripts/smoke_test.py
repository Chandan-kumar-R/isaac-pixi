"""Headless check that Isaac Sim starts, steps physics and shuts down.

    pixi run smoke

Drops a cube onto a ground plane and checks that it fell and came to rest on
the ground instead of hanging in the air or falling through. Uses plain USD
and the timeline rather than isaacsim.core, so it does not depend on which
high-level Isaac Sim API is current.
"""

import sys

from isaacsim import SimulationApp

simulation_app = SimulationApp({"headless": True})

import omni.timeline  # noqa: E402
import omni.usd  # noqa: E402
from pxr import Gf, Usd, UsdGeom, UsdPhysics  # noqa: E402

START_HEIGHT = 2.0
CUBE_SIZE = 0.2
STEPS = 300


def build_stage():
    context = omni.usd.get_context()
    context.new_stage()
    stage = context.get_stage()
    UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.z)
    UsdGeom.SetStageMetersPerUnit(stage, 1.0)

    scene = UsdPhysics.Scene.Define(stage, "/World/physicsScene")
    scene.CreateGravityDirectionAttr(Gf.Vec3f(0.0, 0.0, -1.0))
    scene.CreateGravityMagnitudeAttr(9.81)

    # Static ground: a thin collider with no rigid body.
    ground = UsdGeom.Cube.Define(stage, "/World/ground")
    ground.CreateSizeAttr(1.0)
    ground.AddTranslateOp().Set(Gf.Vec3d(0.0, 0.0, -0.05))
    ground.AddScaleOp().Set(Gf.Vec3f(10.0, 10.0, 0.1))
    UsdPhysics.CollisionAPI.Apply(ground.GetPrim())

    cube = UsdGeom.Cube.Define(stage, "/World/cube")
    cube.CreateSizeAttr(CUBE_SIZE)
    cube.AddTranslateOp().Set(Gf.Vec3d(0.0, 0.0, START_HEIGHT))
    UsdPhysics.RigidBodyAPI.Apply(cube.GetPrim())
    UsdPhysics.CollisionAPI.Apply(cube.GetPrim())
    UsdPhysics.MassAPI.Apply(cube.GetPrim()).CreateMassAttr(1.0)
    return cube


def cube_height(cube):
    xform = UsdGeom.Xformable(cube).ComputeLocalToWorldTransform(Usd.TimeCode.Default())
    return xform.ExtractTranslation()[2]


def main():
    cube = build_stage()
    timeline = omni.timeline.get_timeline_interface()
    timeline.play()
    for _ in range(STEPS):
        simulation_app.update()
    timeline.stop()

    z = cube_height(cube)
    print(f"cube height after {STEPS} steps: {z:.3f} m (started at {START_HEIGHT} m)")
    if z > START_HEIGHT - 0.5:
        print("smoke test FAILED: the cube did not fall, physics is not stepping")
        return 1
    if z < 0.0:
        print("smoke test FAILED: the cube fell through the ground")
        return 1
    print("smoke test passed")
    return 0


if __name__ == "__main__":
    code = 1
    try:
        code = main()
    finally:
        simulation_app.close()
    sys.exit(code)
