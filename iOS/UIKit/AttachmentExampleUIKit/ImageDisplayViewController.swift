//
//  ImageDisplayViewController.swift
//  AttachmentExampleUIKit
//
//  Created by Shunsuke Kondo on 2023/03/14.
//

import UIKit
import DittoSwift

final class ImageDisplayViewController: UIViewController {

    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var progressLabel: UILabel!

    private let attachmentID: String
    private let attachmentToken: DittoAttachmentToken

    private let dittoManager = DittoManager.shared

    
    required init?(coder: NSCoder) { fatalError() }
    init?(coder: NSCoder, attachmentID: String, attachmentToken: DittoAttachmentToken) {
        self.attachmentID = attachmentID
        self.attachmentToken = attachmentToken

        super.init(coder: coder)
    }

    deinit {
        dittoManager.stopFetchingAttachment(id: attachmentID)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        startFetchAttachment()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        dittoManager.stopFetchingAttachment(id: attachmentID)
    }

    private func startFetchAttachment() {
        dittoManager.fetchAttachment(
            id: attachmentID,
            token: attachmentToken,
            progress: { [weak self] percent in
                self?.updateProgress(percent: percent)
            },
            completionHandler: { [weak self] image in
                self?.displayImage(image)
            })
    }

    private func updateProgress(percent: Int) {
        DispatchQueue.main.async { [weak self] in
            self?.progressLabel.text = "\(percent) %"
        }
    }

    private func displayImage(_ image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = image
        }
    }
}
