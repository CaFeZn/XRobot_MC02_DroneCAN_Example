#include "app_framework.hpp"
#include "libxr.hpp"

// Module headers
#include "dronecan_dsdl.hpp"
#include "dronecan_example.hpp"
#include "xrobot_constexpr.hpp"

static void XRobotMain(LibXR::HardwareContainer &hw) {
  using namespace LibXR;
  ApplicationManager appmgr;

  // Auto-generated module instantiations
  static DroneCANDsdl dronecan_dsdl(
      hw,
      appmgr,
      XRobotProjectConstexpr::DroneCANNodeId,
      "can1",
      "timebase",
      "org.libxr.h7.dronecan",
      XRobotProjectConstexpr::DroneCANNodeStatusPeriodMs
  );
  static DroneCANExample dronecan_example(dronecan_dsdl, appmgr);

  while (true) {
    appmgr.MonitorAll();
    Thread::Sleep(1);
  }
}
