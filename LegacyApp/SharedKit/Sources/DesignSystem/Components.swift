import UIKit

// ✅ Fully migrated — @MainActor isolated UIKit components

@MainActor
class BaseViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
    }

    func setupAppearance() {
        view.backgroundColor = .systemBackground
    }
}

@MainActor
class PrimaryButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .systemBlue
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = 12
        titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
    }
}

@MainActor
class LoadingView: UIView {
    private let spinner = UIActivityIndicatorView(style: .large)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(spinner)
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() { spinner.startAnimating(); isHidden = false }
    func hide() { spinner.stopAnimating(); isHidden = true }
}

@MainActor
class ToastView: UIView {
    private let label = UILabel()

    func show(message: String, duration: TimeInterval = 2.0) {
        label.text = message
        isHidden = false
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            isHidden = true
        }
    }
}
