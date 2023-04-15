//
//  InfoModel.swift
//  DoorBird
//
//  Created by Admin on 12/04/2023.
//

import Foundation


// MARK: - InfoResponse
struct InfoResponse: Codable {
    let image: Image?
    let video: Video?
}

// MARK: - Image
struct Image: Codable {
    let url: String?
}

// MARK: - Video
struct Video: Codable {
    let cloud: Cloud?
    let local: [String: Local]?
}

// MARK: - Cloud
struct Cloud: Codable {
    let mjpg: Mjpg?
}

// MARK: - Mjpg
struct Mjpg: Codable {
    let mjpgDefault: Default?

    enum CodingKeys: String, CodingKey {
        case mjpgDefault = "default"
    }
}

// MARK: - Default
struct Default: Codable {
    let port: Int?
    let session, host, key: String?
}

// MARK: - Local
struct Local: Codable {
    let localDefault: Image?

    enum CodingKeys: String, CodingKey {
        case localDefault = "default"
    }
}
