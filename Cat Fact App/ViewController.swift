//
//  ViewController.swift
//  Cat Fact App
//

import UIKit
import WebKit

final class ViewController: UIViewController {
    
    enum UIState {
        case factOnly
        case imageRevealed
    }
    
    lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let r = UITapGestureRecognizer(target: self, action: #selector(onNextTapped))
        r.isEnabled = false
        return r
    }()
    
    private let factLabel = UILabel()
    private let continueLabel = UILabel()
    private let feedbackLabel = UILabel()
    private let showImageButton = UIButton(type: .system)
    private let buttonStack = UIStackView()
    private let labelStack = UIStackView()
    private let mainStack = UIStackView()
    
    private let coverImageView = UIImageView(image: UIImage(named: "image"))
    
    private let catImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let defaults = UserDefaults.standard
    private let yesKey = "yesCount"
    private let noKey  = "noCount"
    private var currentFact: CatFact?
    private var uiState: UIState = .factOnly
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addGestureRecognizer(tapGestureRecognizer)
        view.backgroundColor = .cyan
        setupUI()
        setupLayout()
        updateFeedbackLabel()
        //fetchCatFactAndShow()
        
        Task { await fetchCatFactAndShow() }
    }
    
    private func setupUI() {
        mainStack.axis = .vertical
        mainStack.spacing = 30
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        coverImageView.contentMode = .scaleAspectFit
        coverImageView.clipsToBounds = true
        coverImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // label stack
        labelStack.axis = .vertical
        labelStack.spacing = 24
        labelStack.alignment = .center
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        buttonStack.axis = .vertical
        buttonStack.spacing = 20
        buttonStack.alignment = .center
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        factLabel.text = "Loading a cat fact…"
        factLabel.font = .systemFont(ofSize: 20, weight: .thin)
        factLabel.textColor = .black
        factLabel.textAlignment = .center
        factLabel.numberOfLines = 0
        factLabel.translatesAutoresizingMaskIntoConstraints = false
        
        continueLabel.text = "Tap anywhere for more!"
        continueLabel.font = .systemFont(ofSize: 20, weight: .thin)
        continueLabel.textColor = .black
        continueLabel.textAlignment = .center
        continueLabel.translatesAutoresizingMaskIntoConstraints = false
        continueLabel.isHidden = true
        
        feedbackLabel.font = .systemFont(ofSize: 16, weight: .medium)
        feedbackLabel.textColor = .black
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feedbackLabel)
        let resetLongPress = UILongPressGestureRecognizer(target: self, action: #selector(resetCounts))
        feedbackLabel.isUserInteractionEnabled = true
        feedbackLabel.addGestureRecognizer(resetLongPress)
        
        showImageButton.configuration = .filled()
        showImageButton.setTitle("What?", for: .normal)
        showImageButton.setImage(UIImage(systemName: "photo"), for: .normal)
        showImageButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        showImageButton.tintColor = .white
        showImageButton.addTarget(self, action: #selector(onShowImage), for: .touchUpInside)
        
        mainStack.addArrangedSubview(coverImageView)
        mainStack.addArrangedSubview(labelStack)
        mainStack.addArrangedSubview(buttonStack)
        
        labelStack.addArrangedSubview(factLabel)
        buttonStack.addArrangedSubview(showImageButton)
        
        view.addSubview(continueLabel)
        
        view.addSubview(catImageView)
    }
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainStack.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            feedbackLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            feedbackLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            continueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.9),
            
            coverImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35),
            
            catImageView.leadingAnchor.constraint(equalTo: coverImageView.leadingAnchor),
            catImageView.trailingAnchor.constraint(equalTo: coverImageView.trailingAnchor),
            catImageView.topAnchor.constraint(equalTo: coverImageView.topAnchor),
            catImageView.bottomAnchor.constraint(equalTo: coverImageView.bottomAnchor),
        ])
    }
    
    private func applyState(_ next: UIState) {
        uiState = next
        switch next {
        case .factOnly:
            showFactOnly()
        case .imageRevealed:
            showImageState()
        }
    }
    
    private func showFactOnly() {
        catImageView.isHidden = true
        catImageView.image = nil
        
        coverImageView.isHidden = false
        continueLabel.isHidden = true
        showImageButton.isHidden = false
        tapGestureRecognizer.isEnabled = false
    }
    
    private func showImageState() {
        coverImageView.isHidden = true
        catImageView.isHidden = false
        
        continueLabel.isHidden = false
        showImageButton.isHidden = true
        tapGestureRecognizer.isEnabled = true
        
        catImageView.alpha = 0
        catImageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.8, options: []) {
            self.catImageView.alpha = 1
            self.catImageView.transform = .identity
        }
    }
    
    
    @objc private func onShowImage() {
         guard let url = buildCatImageURL() else { return }
        Task {
            if let image = await fetchCatImage(from: url){
                catImageView.image = image
                applyState(.imageRevealed)
            } else {
                factLabel.text = "Failed to load image"
            }
         }
     }

     @objc private func onNextTapped() {
         askForFeedback()
     }

     private func askForFeedback() {
         let alert = UIAlertController(title: "Enjoyed?", message: "Do you like this one?", preferredStyle: .alert)
         alert.addAction(UIAlertAction(title: "No 👎", style: .default, handler: { _ in
             let v = self.defaults.integer(forKey: self.noKey) + 1
             self.defaults.set(v, forKey: self.noKey)
             self.updateFeedbackLabel()
//             self.fetchCatFactAndShow()
             Task { await self.fetchCatFactAndShow() }
         }))
         alert.addAction(UIAlertAction(title: "Yes 👍", style: .cancel, handler: { _ in
             let v = self.defaults.integer(forKey: self.yesKey) + 1
             self.defaults.set(v, forKey: self.yesKey)
             self.updateFeedbackLabel()
             //self.fetchCatFactAndShow()
             Task { await self.fetchCatFactAndShow() }
         }))
         present(alert, animated: true)
     }

     private func updateFeedbackLabel() {
         let yes = defaults.integer(forKey: yesKey)
         let no  = defaults.integer(forKey: noKey)
         feedbackLabel.text = "👍\(yes)  👎\(no)"
     }

     @objc private func resetCounts() {
         defaults.set(0, forKey: yesKey)
         defaults.set(0, forKey: noKey)
         updateFeedbackLabel()
     }

    private func fetchCatFactAndShow() async {
         applyState(.factOnly)
         factLabel.text = "Loading a cat fact…"
         catImageView.image = nil

         guard let url = URL(string: "https://catfact.ninja/fact") else { return }
         do {
             let (data, _) = try await URLSession.shared.data(from: url)
             let fact = try JSONDecoder().decode(CatFact.self, from: data)
             currentFact = fact
             factLabel.text = fact.fact
         } catch {
             factLabel.text = "failed to load fact"
         }
     }

     private func buildCatImageURL() -> URL? {
         return URL(string: "https://cataas.com/cat?\(UUID().uuidString)")
     }

     private func fetchCatImage(from url: URL) async -> UIImage? {
         do {
             let (data, _) = try await URLSession.shared.data(from: url)
             return UIImage(data: data)
         } catch {
             print("Faile to fetch image")
             return nil
         }
     }
}



//#Preview{
//    ViewController()
//}
