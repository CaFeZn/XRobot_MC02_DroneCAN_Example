#pragma once

#include "app_framework.hpp"
#include "dronecan_core/CanPoller.hpp"
#include "fdcan.h"
#include "gpio.hpp"
#include "main.h"
#include "stm32_canfd.hpp"
#include "stm32_gpio.hpp"
#include "timebase.hpp"

namespace Board
{

class CanPollerAdapter final : public DroneCANCoreSupport::CanPoller
{
 public:
  explicit CanPollerAdapter(LibXR::STM32CANFD& can) : can_(can) {}

  void Poll() override
  {
    while (HAL_FDCAN_GetRxFifoFillLevel(can_.hcan_, FDCAN_RX_FIFO0) > 0U)
    {
      can_.ProcessRxInterrupt(FDCAN_RX_FIFO0);
    }
    while (HAL_FDCAN_GetRxFifoFillLevel(can_.hcan_, FDCAN_RX_FIFO1) > 0U)
    {
      can_.ProcessRxInterrupt(FDCAN_RX_FIFO1);
    }
    can_.TxService();
  }

 private:
  LibXR::STM32CANFD& can_;
};

class HalTimebase final : public LibXR::Timebase
{
 public:
  HalTimebase() : LibXR::Timebase(static_cast<std::uint64_t>(UINT32_MAX) * 1000ULL, UINT32_MAX) {}

  LibXR::MicrosecondTimestamp _get_microseconds() override
  {
    return LibXR::MicrosecondTimestamp(static_cast<std::uint64_t>(HAL_GetTick()) * 1000ULL);
  }

  LibXR::MillisecondTimestamp _get_milliseconds() override
  {
    return LibXR::MillisecondTimestamp(HAL_GetTick());
  }
};

struct Hardware final : public LibXR::HardwareContainer
{
  Hardware(HalTimebase& timebase,
           LibXR::STM32GPIO& led1,
           LibXR::STM32GPIO& led2,
           LibXR::STM32CANFD& can,
           CanPollerAdapter& can_poller)
      : LibXR::HardwareContainer(
            LibXR::Entry<LibXR::Timebase>{timebase, {"timebase", "system_timebase"}},
            LibXR::Entry<LibXR::GPIO>{led1, {"led1", "status_led_1"}},
            LibXR::Entry<LibXR::GPIO>{led2, {"led2", "status_led_2"}},
            LibXR::Entry<LibXR::CAN>{can, {"can1", "fdcan1", "dronecan_bus"}},
            LibXR::Entry<LibXR::FDCAN>{can, {"fdcan1_fd"}},
            LibXR::Entry<DroneCANCoreSupport::CanPoller>{can_poller, {"can1_poller"}}),
        timebase(timebase),
        led1(led1),
        led2(led2),
        can(can),
        can_poller(can_poller)
  {
  }

  HalTimebase& timebase;
  LibXR::STM32GPIO& led1;
  LibXR::STM32GPIO& led2;
  LibXR::STM32CANFD& can;
  CanPollerAdapter& can_poller;
};

Hardware& Get();

Hardware& Init();

}  // namespace Board
