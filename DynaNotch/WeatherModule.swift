import Foundation
import CoreLocation
import SwiftUI

struct HourlyWeather: Identifiable {
    let id: Int          // hour (0-23)
    let hour: Int
    let temp: Double
    let weatherCode: Int // WMO weather code
    let isCurrentHour: Bool
}

/// Open-Meteo API (무료, 키 불필요) + CoreLocation으로 날씨 정보를 가져온다.
final class WeatherModule: NSObject {
    private weak var viewModel: NotchViewModel?
    private let locationManager = CLLocationManager()
    private var refreshTimer: Timer?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.requestWhenInUseAuthorization()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Fetch

    private func fetchWeather(lat: Double, lon: Double) {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code"
            + "&hourly=temperature_2m,weather_code"
            + "&timezone=auto"
            + "&forecast_days=1"

        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let self else { return }
            self.parseResponse(data)
        }.resume()
    }

    private func parseResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // 현재 기온
        let currentTemp: Double
        if let current = json["current"] as? [String: Any],
           let t = current["temperature_2m"] as? Double {
            currentTemp = t
        } else {
            return
        }

        // 시간별 기온 + 날씨 코드
        guard let hourly  = json["hourly"] as? [String: Any],
              let times    = hourly["time"] as? [String],
              let temps    = hourly["temperature_2m"] as? [Double],
              let codes    = hourly["weather_code"] as? [Int] else { return }

        let cal = Calendar.current
        let nowHour = cal.component(.hour, from: Date())

        let todayPrefix: String = {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            return fmt.string(from: Date())
        }()

        var hourly24: [HourlyWeather] = []
        for (i, time) in times.enumerated() {
            guard i < temps.count, i < codes.count,
                  time.hasPrefix(todayPrefix) else { continue }
            let hour = cal.component(.hour, from: iso8601(time) ?? Date())
            hourly24.append(HourlyWeather(
                id: hour,
                hour: hour,
                temp: temps[i],
                weatherCode: codes[i],
                isCurrentHour: hour == nowHour
            ))
        }

        DispatchQueue.main.async { [weak self] in
            guard let vm = self?.viewModel else { return }
            let tempStr = "\(Int(currentTemp.rounded()))°"
            vm.rightContent = .weather(temp: tempStr)
            vm.weatherHourly = hourly24
        }
    }

    private func iso8601(_ str: String) -> Date? {
        // "2024-01-01T13:00" 형식
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return fmt.date(from: str)
    }

    // MARK: - Refresh

    private func scheduleRefresh(lat: Double, lon: Double) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.fetchWeather(lat: lat, lon: lon)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherModule: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        fetchWeather(lat: lat, lon: lon)
        scheduleRefresh(lat: lat, lon: lon)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패 시 서울 기본값
        fetchWeather(lat: 37.5665, lon: 126.9780)
    }
}
