//
//  ToDoListViewController.swift
//  ToDoListApp
//
//  Created by Cory Kim on 2020/04/06.
//  Copyright © 2020 corykim0829. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {
      
    @IBOutlet weak var stackView: UIStackView!
    private var userInfo: UserInfo!
    private var tokenManager: TokenManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTokenManager()
        checkToken()
    }
    
    private func configureTokenManager() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.tokenManager = appDelegate?.tokenManager
    }
    
    private func checkToken() {
        if let token = loadToken() {
            fetchUserInfo(with: token, completion: {
                self.configureToDoList(with: token)
            })
        } else {
            presentToLogIn()
        }
    }
    
    private func loadToken() -> String? {
        tokenManager.loadToken()
        return tokenManager.token
    }
    
    private func saveToken(_ token: String?) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let tokenManager = appDelegate?.tokenManager
        tokenManager?.saveToken(token)
    }
    
    private func presentToLogIn() {
        let logInViewController = storyboard?.instantiateViewController(identifier: LogInViewController.identifier) as! LogInViewController
        logInViewController.modalPresentationStyle = .fullScreen
        present(logInViewController, animated: true, completion: {
            logInViewController.delegate = self
        })
    }
    
    private func configureToDoList(with token: String) {
        requestColumnsData(with: token) { (columns) in
            DispatchQueue.main.async {
                self.configureColumns(columns)
            }
        }
    }
    
    private func resetColumnViewControllers() {
        children.forEach {
            $0.removeFromParent()
        }
        stackView.removeAll()
    }
    
    private func configureColumns(_ columns: [Column]) {
        resetColumnViewControllers()
        for column in columns {
            guard let columnViewController = storyboard?.instantiateViewController(identifier: ColumnViewController.identifier) as? ColumnViewController else { return }
            self.addChild(columnViewController)
            self.stackView.addArrangedSubview(columnViewController.view)
            columnViewController.columnViewModel = ColumnViewModel()
            columnViewController.configureColumnViewModel(with: column)
            columnViewController.configureColumnId(column.identifier)
            columnViewController.configureUserInfo(userInfo)
        }
    }
    
    @IBAction func userInfoButtonTapped(_ sender: UIBarButtonItem) {
//        guard let userInfo = userInfo else { return }
        guard let userInfoViewController = storyboard?.instantiateViewController(identifier: UserInfoViewController.identifier) as? UserInfoViewController else { return }
        userInfoViewController.modalPresentationStyle = .popover
        self.present(userInfoViewController, animated: true) {
            userInfoViewController.updateUserInfoView(with: self.userInfo)
            userInfoViewController.delegate = self
        }
        userInfoViewController.popoverPresentationController?.barButtonItem = sender
    }
}

extension HomeViewController {
    
    // MARK:- Network
    private func requestColumnsData(with token: String, completion: @escaping ([Column]) -> Void) {
        NetworkManager.shared.requestData(path: "/api/columns", token: token) { (result: Result<UserData, RequestError>) in
            switch result {
            case .success(let userData):
                completion(userData.columns)
            case .failure(let error):
                self.showErrorAlert(error: error)
            }
        }
    }
    
    private func fetchUserInfo(with token: String, completion: @escaping () -> Void) {
        NetworkManager.shared.requestData(path: "/api/userInfo", token: token) { (result: Result<UserInfo, RequestError>) in
            switch result {
            case .success(let userInfo):
                self.userInfo = userInfo
                completion()
            case .failure(_):
                break
            }
        }
    }
}

extension HomeViewController {
    
    // MARK:- AlertViewController
    private func showErrorAlert(error: RequestError) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: error.description, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Done", style: .default, handler: nil)
            let retryAction = UIAlertAction(title: "Retry", style: .cancel) { _ in
                self.configureToDoList(with: "")
            }
            alert.addAction(retryAction)
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension HomeViewController: UserInfoViewControllerDelegate {
    func didTapSignOut() {
        saveToken(nil)
        checkToken()
    }
}

extension HomeViewController: LogInViewControllerDelegate {
    func didSuccessToLogIn(with token: String) {
        saveToken(token)
        checkToken()
    }
}
