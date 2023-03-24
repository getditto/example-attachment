//
//  DittoManager.swift
//  AttachmentExampleUIKit
//
//  Created by Shunsuke Kondo on 2023/03/09.
//

import UIKit
import Combine
import DittoSwift
import DittoPresenceViewer

// Documentation: https://docs.ditto.live/


final class DittoManager {

    static let shared = DittoManager()

    private var ditto: Ditto? = nil

    private var collection: DittoCollection? = nil

    private var subscription: DittoSubscription? = nil

    private var liveQuery: DittoLiveQuery? = nil

    @Published private(set) var attachmentTokens = [[String: DittoAttachmentToken]]()

    private var attachmentFetchers = [[String: DittoAttachmentFetcher?]]()

    private var fileManager = FileManager.default

    // Create your app in Portal: https://portal.ditto.live/
    private let appID = "<Use Your App ID>"
    private let authToken = "<Use Your Auth Token>"

    private init() {
        setupDitto()
        startDittoSync()
        observeCollection()
    }

    private func setupDitto() {

        DittoLogger.minimumLogLevel = .verbose

        // Disabling cloud sync here for BLE sync test, please make it `true` if you want to test cloud sync!
        let enableCloudSync = false

        ditto = Ditto(identity: .onlinePlayground(appID: appID, token: authToken, enableDittoCloudSync: enableCloudSync))

        ditto?.updateTransportConfig { config in

            // Disabling AWDL(Wi-Fi direct) and LAN sync here to test sync only on BLE
            // Please make them `true` to enable those transports
            config.peerToPeer.awdl.isEnabled = false
            config.peerToPeer.lan.isEnabled = false
        }

        collection = ditto?.store.collection("attachments")
    }

    private func startDittoSync() {
        do {
            try ditto?.startSync()
        } catch {
            assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
        }
    }

    private func observeCollection() {
        guard let collection = collection else { assertionFailure(); return }

        subscription = collection.findAll().subscribe()

        liveQuery = collection.findAll().observeLocal(deliverOn: .global(qos: .default)) { [weak self] docs, event in

            self?.attachmentTokens = docs.compactMap { doc in
                guard let attachment = doc["attachment"].attachmentToken else { assertionFailure(); return nil }
                let docID = doc.id.stringValue

                return [docID: attachment]
            }

            print("attachment tokens: \(self?.attachmentTokens ?? [])")
        }
    }

    // MARK: - Internal Access

    func fetchAttachment(
        id: String,
        token: DittoAttachmentToken,
        progress: @escaping (_ percent: Int) -> Void,
        completionHandler: @escaping (_ image: UIImage) -> Void
    ) {
        let fetcher = collection?.fetchAttachment(token: token) { [weak self] event in
            guard let self = self else { return }

            switch event {
            case .progress(let downloadedBytes, let totalBytes):
                let percent = Int(Double(downloadedBytes) / Double(totalBytes) * 100)
                progress(percent)

            case .completed(let attachment):
                do {
                    let data = try attachment.getData()
                    if let image = UIImage(data: data) {
                        completionHandler(image)
                    }
                } catch {
                    assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
                }

            case .deleted:
                self.attachmentFetchers.removeAll(where: { $0.keys.first == id })

            @unknown default:
                self.attachmentFetchers.removeAll(where: { $0.keys.first == id })

                assertionFailure("unknown case \(#function)")
            }
        }

        attachmentFetchers.append([id: fetcher])
    }

    func stopFetchingAttachment(id: String) {
        guard let attachment = attachmentFetchers.first(where: { $0.keys.first == id }) else { return }
        guard let fetcherOptional = attachment[id] else { return }
        guard let fetcher = fetcherOptional else { return }

        fetcher.stop()
        attachmentFetchers.removeAll(where: { $0.keys.first == id })
    }

    var presenceViewer: UIViewController? {
        guard let ditto = ditto else { assertionFailure(); return nil }
        return DittoPresenceView(ditto: ditto).viewController
    }
}


// MARK: - Image

extension DittoManager {

    func insertNewImage(_ image: UIImage) {
        let url = writeToLocal(image)
        insertNewAttachmentToCollection(url)

        // remove the local file after inserting to collection
        removeLocalFile(url)
    }

    /// Data needs to be written locally first to be an attachment
    private func writeToLocal(_ image: UIImage) -> URL {
        let url = fileURL(image: image)
        guard let data = imageData(image) else { assertionFailure(); return URL(fileURLWithPath: "") }

        do {
            try data.write(to: url)
            print("Success write image \(data.count) bytes")
        } catch {
            assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
        }

        return url
    }

    private func removeLocalFile(_ url: URL) {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
        }
    }

    private func imageData(_ image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: 1.0)
    }

    private var imageDirectory: URL {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("files", isDirectory: true)

        if !fileManager.fileExists(atPath: dir.absoluteString) {
            do {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
            }
        }

        return dir
    }

    private func fileURL(image: UIImage) -> URL {
        return imageDirectory.appendingPathComponent("\(image.hashValue).jpg")
    }

    private func insertNewAttachmentToCollection(_ url: URL) {
        guard let collection = collection else { assertionFailure(); return }
        guard let attachment = collection.newAttachment(path: url.path) else { assertionFailure(); return }

        // using url as doc ID here as an example
        let docID = url.lastPathComponent

        do {
            try collection.upsert(["_id": docID, "attachment": attachment])
            print("Success insert attachment \(docID)\n")
        } catch {
            assertionFailure("\(#function) ERROR: \(error.localizedDescription)")
        }
    }
}
