//
//  ViewController.swift
//  AttachmentExampleUIKit
//
//  Created by Shunsuke Kondo on 2023/03/09.
//

import UIKit
import PhotosUI

final class ViewController: UIViewController {

    private let dittoManager = DittoManager.shared

    private var photoPicker: PHPickerViewController!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupPhotoPicker()
    }

    private func setupNavigationBar() {
        title = "Attachments"

        let plusButton = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .done, target: self, action: #selector(plusDidTap))
        navigationItem.rightBarButtonItem = plusButton
    }

    @objc private func plusDidTap() {
        present(photoPicker, animated: true)
    }

}

// MARK: - Photo Picker

extension ViewController: PHPickerViewControllerDelegate {

    private func setupPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images

        photoPicker = PHPickerViewController(configuration: configuration)
        photoPicker.delegate = self
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        photoPicker.dismiss(animated: true)

        guard let itemProvider = results.first?.itemProvider else { assertionFailure(); return }
        guard itemProvider.canLoadObject(ofClass: UIImage.self) else { assertionFailure(); return }

        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard error == nil else { return }
            guard let image = object as? UIImage else { return }
            self?.imagePicked(image)
        }
    }

    private func imagePicked(_ image: UIImage) {
        DittoManager.shared.insertNewImage(image)
    }


}
