//
//  ActivityState.swift
//  Globes
//
//  Created by BooSung Jung on 31/7/2024.
//

import CoreFoundation
import Foundation
import RealityFoundation

/// When I initially shared globeConfiguration there were conflicts because visionPro A was refering to globeConfiguration and visionPro B was also refering to globeConfiguration and not everything was getting updated properly
/// so instead i am sharing loadGlobe which is a bool which triggers whenever i load a globe using the button in GlobeButton.swift
/// and loadGlobe = false whenever i hide the globe
/// So maybe I should be sharing an intermediate class instead. For example
///
/// VisionPro A has its own globeConfiguration class which refers to ----> ActivityState <---- Vision pro B has its own globeConfiguration which also refers to activity state
/// and any changes to the activityState we can reflect it on VisionPro A and B. This will work even with more players.
///
/// Previously i had VisionPro A ----> ActivityStates GlobeConfiguration variable <---- Vision Pro B
/// and since both VisionPro A and B were refering to the same globeConfiguration whenever there was a change in state it was much difficult to know
/// if the change in state happened in VisionPro A or B
///
/// But by implementing this new strategy we now can compare the current globeConfiguration with the ActivityState and update accordingly.
struct ActivityState: Codable, Equatable {
    var loadGlobe: Bool = false
    
    // for some reason Transform crashes the app for vision pro version < 2.0
//    var globeTransformation:Transform?
    var tempTranslation:TempTranslation?
    
}

struct TempTranslation: Codable, Equatable {
    var scale: Float?
    var orientation: simd_quatf?
    var position: SIMD3<Float>?

    init(scale: Float? = nil, orientation: simd_quatf?, position: SIMD3<Float>?) {
        self.scale = scale
        self.orientation = orientation
        self.position = position
    }

    // Custom Codable implementation
    enum CodingKeys: String, CodingKey {
        case scale
        case orientation
        case position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = try container.decodeIfPresent(Float.self, forKey: .scale)
        position = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .position)
        
        if let orientationArray = try container.decodeIfPresent([Float].self, forKey: .orientation), orientationArray.count == 4 {
            orientation = simd_quatf(ix: orientationArray[0], iy: orientationArray[1], iz: orientationArray[2], r: orientationArray[3])
        } else {
            orientation = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(position, forKey: .position)
        
        if let orientation = orientation {
            let orientationArray = [orientation.imag.x, orientation.imag.y, orientation.imag.z, orientation.real]
            try container.encode(orientationArray, forKey: .orientation)
        }
    }
}
