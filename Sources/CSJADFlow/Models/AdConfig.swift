import Foundation

public struct AdConfig: Codable {
    public let umKey: String?
    public let bId: String?
    public let appId: String
    public let rewardSlotId: [String]
    public let splashSlotId: [String]
    public let interstitialSlotId: [String]
    public let isEnable: Bool
    public let cacheLength: Int
    public let flows: [FlowItem]
}
