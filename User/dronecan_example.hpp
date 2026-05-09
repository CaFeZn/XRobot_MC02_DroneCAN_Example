#pragma once

#include <cstdint>

#include "dronecan_dsdl.hpp"

class DroneCANExample final : public LibXR::Application
{
 public:
  using RawCommand = DroneCANGeneratedDsdl::uavcan::equipment::esc::RawCommand;
  using Status = DroneCANGeneratedDsdl::uavcan::equipment::esc::Status;
  using RawCommandTopicData = DroneCANDsdl::UavcanEquipmentEscRawCommandTopicData;
  using StatusTopicData = DroneCANDsdl::UavcanEquipmentEscStatusTopicData;

  DroneCANExample(DroneCANDsdl& dronecan, LibXR::ApplicationManager& appmgr)
      : dronecan_(dronecan),
        raw_command_tx_topic_(dronecan.UavcanEquipmentEscRawCommandTxTopic()),
        status_rx_topic_(dronecan.UavcanEquipmentEscStatusTopic()),
        status_rx_topic_callback_(LibXR::Topic::Callback::Create(OnStatusTopicStatic,
                                                                  this))
  {
    dronecan_.SetUavcanEquipmentEscRawCommandCallback(this,
                                                      OnRawCommandNormalStatic);
    status_rx_topic_.RegisterCallback(status_rx_topic_callback_);
    appmgr.Register(*this);
  }

  void OnMonitor() override
  {
    const auto now_ms = static_cast<std::uint32_t>(LibXR::Timebase::GetMilliseconds());
    if (!timing_initialized_)
    {
      last_normal_tx_ms_ = now_ms - kNormalTxPeriodMs;
      last_topic_tx_ms_ = now_ms - kTopicTxPeriodMs;
      timing_initialized_ = true;
    }

    if ((now_ms - last_normal_tx_ms_) >= kNormalTxPeriodMs)
    {
      last_normal_tx_ms_ = now_ms;
      PublishNormalStatus();
    }

    if ((now_ms - last_topic_tx_ms_) >= kTopicTxPeriodMs)
    {
      last_topic_tx_ms_ = now_ms;
      PublishTopicRawCommand();
    }
  }

 private:
  static constexpr std::uint32_t kNormalTxPeriodMs = 1000U;
  static constexpr std::uint32_t kTopicTxPeriodMs = 1500U;

  static void OnRawCommandNormalStatic(
      void* context, const LibXR::DroneCAN::TransferMetadata& metadata,
      const RawCommand& message)
  {
    auto* self = static_cast<DroneCANExample*>(context);
    if (self != nullptr)
    {
      self->OnRawCommandNormal(metadata, message);
    }
  }

  void OnRawCommandNormal(const LibXR::DroneCAN::TransferMetadata& metadata,
                          const RawCommand& message) noexcept
  {
    last_normal_rx_metadata_ = metadata;
    last_normal_rx_raw_command_ = message;
    ++normal_rx_count_;
  }

  static void OnStatusTopicStatic(bool, DroneCANExample* self, LibXR::RawData& data)
  {
    if (self != nullptr)
    {
      self->OnStatusTopic(data);
    }
  }

  void OnStatusTopic(LibXR::RawData& data) noexcept
  {
    if ((data.addr_ == nullptr) || (data.size_ != sizeof(StatusTopicData)))
    {
      return;
    }

    last_topic_rx_status_ = *reinterpret_cast<const StatusTopicData*>(data.addr_);
    ++topic_rx_count_;
  }

  void PublishNormalStatus()
  {
    Status status{};
    status.error_count = normal_tx_count_;
    status.voltage = 24.0F;
    status.current = 1.0F + (static_cast<float>(normal_tx_count_ % 10U) * 0.1F);
    status.temperature = 35.0F;
    status.rpm = static_cast<std::int32_t>(2000 + ((normal_tx_count_ % 50U) * 20U));
    status.power_rating_pct = 50U;
    status.esc_index = 0U;

    (void)dronecan_.PublishUavcanEquipmentEscStatus(status,
                                                    CANARD_TRANSFER_PRIORITY_LOW);
    ++normal_tx_count_;
  }

  void PublishTopicRawCommand()
  {
    RawCommandTopicData topic_data{};
    const auto command =
        static_cast<std::int16_t>(100 + static_cast<int>(topic_tx_count_ % 50U));

    topic_data.metadata.priority = CANARD_TRANSFER_PRIORITY_MEDIUM;
    topic_data.message.cmd_size = 4U;
    topic_data.message.cmd[0] = command;
    topic_data.message.cmd[1] = command;
    topic_data.message.cmd[2] = command;
    topic_data.message.cmd[3] = command;

    raw_command_tx_topic_.Publish(topic_data);
    ++topic_tx_count_;
  }

  DroneCANDsdl& dronecan_;
  LibXR::Topic raw_command_tx_topic_;
  LibXR::Topic status_rx_topic_;
  LibXR::Topic::Callback status_rx_topic_callback_;
  bool timing_initialized_ = false;
  std::uint32_t last_normal_tx_ms_ = 0U;
  std::uint32_t last_topic_tx_ms_ = 0U;
  std::uint32_t normal_tx_count_ = 0U;
  std::uint32_t topic_tx_count_ = 0U;
  std::uint32_t normal_rx_count_ = 0U;
  std::uint32_t topic_rx_count_ = 0U;
  LibXR::DroneCAN::TransferMetadata last_normal_rx_metadata_{};
  RawCommand last_normal_rx_raw_command_{};
  StatusTopicData last_topic_rx_status_{};
};
