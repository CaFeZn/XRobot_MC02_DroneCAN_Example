#include "board.hpp"
#include "xrobot_main.hpp"

extern "C" void XRobotAppMain(void)
{
  auto& hardware = Board::Init();
  XRobotMain(hardware);
}
