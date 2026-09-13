import UIKit
import WebKit
import UniformTypeIdentifiers

final class WebViewController: UIViewController {
    static let homeURL = URL(string: "https://868686869.xyz/quan-ly-nha-tro/")!
    private static let allowedHosts: Set<String> = ["868686869.xyz", "www.868686869.xyz"]
    private static let bridgeNames = ["nt365CopyText", "nt365CopyImage", "nt365OpenExternal"]

    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let refreshButton = UIButton(type: .system)
    private let refreshSpinner = UIActivityIndicatorView(style: .medium)
    private let refreshControl = UIRefreshControl()
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private var progressObservation: NSKeyValueObservation?
    private var pendingNotificationURL: URL?
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1)
        configureWebView()
        configureOverlayControls()
        configureErrorView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pushTokenDidChange(_:)),
            name: .nt365PushTokenDidChange,
            object: nil
        )
        loadHome()
    }

    deinit {
        progressObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
        Self.bridgeNames.forEach { webView?.configuration.userContentController.removeScriptMessageHandler(forName: $0) }
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = true

        let contentController = WKUserContentController()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let token = PushTokenStore.shared.token
        let script = Self.mobileBridgeScript(version: version, pushToken: token)
        contentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        Self.bridgeNames.forEach { contentController.add(self, name: $0) }
        configuration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.customUserAgent = Self.userAgent(version: version)
        webView.scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(reloadFromOrigin), for: .valueChanged)
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.progress = Float(webView.estimatedProgress)
                self?.progressView.isHidden = webView.estimatedProgress >= 1
            }
        }
    }

    private func configureOverlayControls() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = UIColor(red: 0.03, green: 0.44, blue: 0.36, alpha: 1)
        progressView.trackTintColor = .clear
        view.addSubview(progressView)

        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        refreshButton.tintColor = UIColor(red: 0.04, green: 0.25, blue: 0.34, alpha: 1)
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.layer.cornerRadius = 22
        refreshButton.layer.shadowColor = UIColor.black.cgColor
        refreshButton.layer.shadowOpacity = 0.16
        refreshButton.layer.shadowRadius = 7
        refreshButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        refreshButton.accessibilityLabel = "Tải lại"
        refreshButton.addTarget(self, action: #selector(reloadFromOrigin), for: .touchUpInside)
        view.addSubview(refreshButton)

        refreshSpinner.translatesAutoresizingMaskIntoConstraints = false
        refreshSpinner.hidesWhenStopped = true
        refreshSpinner.color = refreshButton.tintColor
        refreshButton.addSubview(refreshSpinner)

        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            refreshButton.widthAnchor.constraint(equalToConstant: 44),
            refreshButton.heightAnchor.constraint(equalToConstant: 44),
            refreshButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10),
            refreshButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            refreshSpinner.centerXAnchor.constraint(equalTo: refreshButton.centerXAnchor),
            refreshSpinner.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
        ])
    }

    private func configureErrorView() {
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1)
        errorView.isHidden = true

        let title = UILabel()
        title.text = "Không tải được dữ liệu"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textColor = UIColor(red: 0.04, green: 0.13, blue: 0.19, alpha: 1)
        title.textAlignment = .center

        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.textColor = .secondaryLabel

        let retry = UIButton(type: .system)
        retry.configuration = .filled()
        retry.configuration?.title = "Thử lại"
        retry.addTarget(self, action: #selector(reloadFromOrigin), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, errorLabel, retry])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        errorView.addSubview(stack)
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
        ])
    }

    private func loadHome() {
        hideError()
        webView.load(URLRequest(url: Self.homeURL, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    @objc private func reloadFromOrigin() {
        hideError()
        beginLoading()
        if webView.url == nil {
            loadHome()
        } else {
            webView.reloadFromOrigin()
        }
    }

    private func beginLoading() {
        refreshButton.setImage(nil, for: .normal)
        refreshSpinner.startAnimating()
        refreshButton.isEnabled = false
    }

    private func finishLoading() {
        refreshControl.endRefreshing()
        refreshSpinner.stopAnimating()
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.isEnabled = true
    }

    private func showError(_ message: String) {
        finishLoading()
        errorLabel.text = message
        errorView.isHidden = false
        view.bringSubviewToFront(errorView)
        view.bringSubviewToFront(refreshButton)
    }

    private func hideError() {
        errorView.isHidden = true
    }

    func queueNotificationURL(_ url: URL) {
        guard Self.isAllowedInternalURL(url) else { return }
        guard isViewLoaded, webView != nil else {
            pendingNotificationURL = url
            return
        }
        pendingNotificationURL = nil
        webView.load(URLRequest(url: url))
    }

    @objc private func pushTokenDidChange(_ notification: Notification) {
        guard let token = notification.object as? String else { return }
        updatePushTokenInPage(token)
    }

    private func updatePushTokenInPage(_ token: String) {
        let quoted = Self.javascriptLiteral(token)
        webView.evaluateJavaScript("if(window.NT365Mobile){window.NT365Mobile._setPushToken(\(quoted));}if(window.NT365RegisterPushDevice){window.NT365RegisterPushDevice();}")
    }

    private func openExternal(_ url: URL) {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""
        guard scheme == "zalo" || (scheme == "https" && host == "zalo.me") else { return }
        UIApplication.shared.open(url, options: [:])
    }

    private func copyImageDataURL(_ value: String) {
        guard value.hasPrefix("data:image/png;base64,"),
              let separator = value.firstIndex(of: ","),
              let data = Data(base64Encoded: String(value[value.index(after: separator)...]), options: .ignoreUnknownCharacters),
              data.count <= 10 * 1024 * 1024,
              UIImage(data: data) != nil else { return }
        UIPasteboard.general.setData(data, forPasteboardType: UTType.png.identifier)
    }

    static func isAllowedInternalURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return allowedHosts.contains(host)
    }

    private static func userAgent(version: String) -> String {
        "Mozilla/5.0 (iPhone; CPU iPhone OS like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 NhaTro365IOS/\(version)"
    }

    private static func javascriptLiteral(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [value]),
              let json = String(data: data, encoding: .utf8),
              json.count >= 2 else { return "\"\"" }
        return String(json.dropFirst().dropLast())
    }

    private static func mobileBridgeScript(version: String, pushToken: String) -> String {
        let versionValue = javascriptLiteral(version)
        let tokenValue = javascriptLiteral(pushToken)
        return """
        (function(){
          var pushToken=\(tokenValue);
          function post(name,value){
            try{window.webkit.messageHandlers[name].postMessage(String(value||''));return true;}catch(error){return false;}
          }
          window.NT365Mobile={
            getPlatform:function(){return 'ios';},
            getVersion:function(){return \(versionValue);},
            getDeviceName:function(){return 'iPhone';},
            getPushToken:function(){return pushToken;},
            _setPushToken:function(value){pushToken=String(value||'');},
            copyText:function(value){return post('nt365CopyText',value);},
            copyImage:function(value){return post('nt365CopyImage',value);},
            openExternal:function(value){return post('nt365OpenExternal',value);}
          };
        })();
        """
    }

    private func uniqueDownloadURL(filename: String) -> URL {
        let clean = filename.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var destination = documents.appendingPathComponent(clean.isEmpty ? "tai-lieu" : clean)
        if FileManager.default.fileExists(atPath: destination.path) {
            let base = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            let stamp = Int(Date().timeIntervalSince1970)
            destination = documents.appendingPathComponent("\(base)-\(stamp)\(ext.isEmpty ? "" : ".\(ext)")")
        }
        return destination
    }

    private func presentDownloadedFile(_ url: URL) {
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = share.popoverPresentationController {
            popover.sourceView = refreshButton
            popover.sourceRect = refreshButton.bounds
        }
        present(share, animated: true)
    }
}

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let value = message.body as? String else { return }
        switch message.name {
        case "nt365CopyText":
            UIPasteboard.general.string = value
        case "nt365CopyImage":
            copyImageDataURL(value)
        case "nt365OpenExternal":
            guard let url = URL(string: value) else { return }
            openExternal(url)
        default:
            break
        }
    }
}

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hideError()
        beginLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoading()
        updatePushTokenInPage(PushTokenStore.shared.token)
        if let pending = pendingNotificationURL {
            queueNotificationURL(pending)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError("Vui lòng kiểm tra kết nối mạng rồi thử lại.\n\(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reloadFromOrigin()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == "about" || Self.isAllowedInternalURL(url) {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
            return
        }
        if ["https", "mailto", "tel", "zalo"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url, options: [:])
        }
        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if #available(iOS 14.5, *),
           let response = navigationResponse.response as? HTTPURLResponse {
            let disposition = response.value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
            if disposition.contains("attachment") || !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
                return
            }
        }
        decisionHandler(.allow)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

extension WebViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        if Self.isAllowedInternalURL(url) {
            webView.load(navigationAction.request)
        } else {
            UIApplication.shared.open(url, options: [:])
        }
        return nil
    }
}

@available(iOS 14.5, *)
extension WebViewController: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let destination = uniqueDownloadURL(filename: suggestedFilename)
        downloadDestinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        presentDownloadedFile(destination)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
        showError("Không tải được tài liệu. \(error.localizedDescription)")
    }
}
