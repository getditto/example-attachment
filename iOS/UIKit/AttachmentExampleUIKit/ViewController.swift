//
//  ViewController.swift
//  AttachmentExampleUIKit
//
//  Created by Shunsuke Kondo on 2023/03/09.
//

import UIKit
import Combine
import PhotosUI

final class ViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView! {
        didSet {
            setupTableView()
        }
    }

    private let dittoManager = DittoManager.shared

    private var photoPicker: PHPickerViewController!

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        observeDitto()
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

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    private func observeDitto() {
        dittoManager.$attachmentTokens
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            }.store(in: &cancellables)
    }

}

// MARK: - TableView

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dittoManager.attachmentTokens.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let attachmentToken = dittoManager.attachmentTokens[indexPath.row]

        cell.textLabel?.text = attachmentToken.keys.first
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let attachmentToken = dittoManager.attachmentTokens[indexPath.row].values.first else {
            assertionFailure(); return
        }
        guard let attachmentID = dittoManager.attachmentTokens[indexPath.row].keys.first else {
            assertionFailure(); return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier = "ImageDisplayViewController"

        let vc = storyboard.instantiateViewController(identifier: identifier) { coder in
            ImageDisplayViewController(coder: coder, attachmentID: attachmentID, attachmentToken: attachmentToken)
        }

        navigationController?.pushViewController(vc, animated: true)

        tableView.deselectRow(at: indexPath, animated: true)
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

        guard let itemProvider = results.first?.itemProvider else { return }
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
