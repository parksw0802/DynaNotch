import AudioToolbox
import CoreAudio
import Foundation

/// CoreAudio를 통해 시스템 기본 출력 장치의 볼륨을 읽고 씁니다.
enum VolumeController {

    static func getVolume() -> Float {
        guard let deviceID = defaultOutputDeviceID() else { return 0 }
        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume)
        return volume
    }

    static func setVolume(_ volume: Float) {
        guard let deviceID = defaultOutputDeviceID() else { return }
        var v = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &v)
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }
}
