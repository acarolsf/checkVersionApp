//
//  ViewController.swift
//  checkVersionApp
//
//  Created by Ana Carolina Ferreira on 27/04/23.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private lazy var button: UIButton = {
        let button = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Clique aqui", for: .normal)
        button.backgroundColor = .blue
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(checkVersion), for: .touchUpInside)
        return button
    }()
    
    func setupUI() {
        self.view.backgroundColor = .white
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc func checkVersion() {
        CheckUpdate.shared.showUpdate(withConfirmation: true, isTestFlight: true)
    }
}

