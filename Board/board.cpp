#include "board.hpp"

#include "dronecan_core/CanPoller.hpp"
#include "libxr.hpp"
#include "libxr_rw.hpp"
#include "usbd_cdc_if.h"

namespace Board
{

namespace
{

LibXR::ErrorCode UsbCdcWrite(LibXR::WritePort& port, bool)
{
  LibXR::WriteInfoBlock info{};
  if (port.queue_info_->Pop(info) != LibXR::ErrorCode::OK)
  {
    return LibXR::ErrorCode::EMPTY;
  }

  const uint8_t* payload = static_cast<const uint8_t*>(info.data.addr_);
  uint32_t tries = 2000U;
  while (tries-- > 0U)
  {
    if (CDC_Transmit_HS(const_cast<uint8_t*>(payload),
                        static_cast<uint16_t>(info.data.size_)) == USBD_OK)
    {
      port.Finish(false, LibXR::ErrorCode::OK, info);
      return LibXR::ErrorCode::OK;
    }
    HAL_Delay(1);
  }

  port.Finish(false, LibXR::ErrorCode::BUSY, info);
  return LibXR::ErrorCode::BUSY;
}

}  // namespace

Hardware& Init()
{
  static HalTimebase timebase;
  static LibXR::STM32GPIO led1(LCD_BLK_GPIO_Port, LCD_BLK_Pin);
  static LibXR::STM32GPIO led2(POWER_5V_GPIO_Port, POWER_5V_Pin);
  static LibXR::STM32CANFD can(&hfdcan1, 32);
  static CanPollerAdapter can_poller(can);
  static Hardware hardware(timebase, led1, led2, can, can_poller);

  const LibXR::GPIO::Configuration output_config{
      LibXR::GPIO::Direction::OUTPUT_PUSH_PULL, LibXR::GPIO::Pull::NONE};
  (void)led1.SetConfig(output_config);
  (void)led2.SetConfig(output_config);
  led1.Write(false);
  led2.Write(true);

  LibXR::CAN::Configuration can_config{};
  can_config.bitrate = 1000000U;
  can_config.sample_point = 0.60F;
  can_config.bit_timing.brp = 24U;
  can_config.bit_timing.prop_seg = 1U;
  can_config.bit_timing.phase_seg1 = 1U;
  can_config.bit_timing.phase_seg2 = 2U;
  can_config.bit_timing.sjw = 1U;
  can_config.mode.one_shot = false;
  (void)can.SetConfig(can_config);
  (void)HAL_FDCAN_ConfigGlobalFilter(&hfdcan1,
                                     FDCAN_ACCEPT_IN_RX_FIFO0,
                                     FDCAN_ACCEPT_IN_RX_FIFO0,
                                     FDCAN_REJECT_REMOTE,
                                     FDCAN_REJECT_REMOTE);
  (void)HAL_FDCAN_ActivateNotification(
      &hfdcan1, FDCAN_IT_RX_FIFO0_NEW_MESSAGE | FDCAN_IT_RX_FIFO1_NEW_MESSAGE, 0);
  static LibXR::WritePort usb_write_port(8, 256);
  usb_write_port = UsbCdcWrite;
  LibXR::STDIO::write_ = &usb_write_port;

  return hardware;
}

Hardware& Get()
{
  return Init();
}

}  // namespace Board
