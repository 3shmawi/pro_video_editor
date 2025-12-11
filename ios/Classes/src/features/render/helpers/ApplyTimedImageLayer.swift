import Foundation

func applyTimedImageLayer(
    config: inout VideoCompositorConfig,
    timedLayer: TimedImageLayer
) {
    config.timedImageLayers.append(timedLayer)
    print("[Render] Added timed image layer: \(timedLayer.startTimeUs/1000000)s - \(timedLayer.endTimeUs/1000000)s")
}
