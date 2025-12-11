import Foundation

struct TimedImageLayer {
    let imageData: Data
    let startTimeUs: Int64
    let endTimeUs: Int64
    
    func isVisibleAt(timeUs: Int64) -> Bool {
        return timeUs >= startTimeUs && timeUs <= endTimeUs
    }
}
