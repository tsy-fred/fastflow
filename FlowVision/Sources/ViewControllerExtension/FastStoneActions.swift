import Cocoa

extension ViewController {

    /// 批量重命名（Phase 4a）
    /// Batch rename
    func handleBatchRename() {
        let urls = publicVar.selectedUrls()
        guard !urls.isEmpty else { return }

        BatchRenamePanel.show(urls: urls) { [weak self] renamed in
            if !renamed.isEmpty {
                self?.publicVar.fileChangedCount += renamed.count
                if let first = renamed.first?.absoluteString {
                    self?.publicVar.filesForLocateAfterChange = [first]
                    self?.publicVar.filesForLocateAfterChangeTime = .now()
                }
                self?.scheduledRefresh()
            }
        }
    }

    /// 批量转换（Phase 4b）
    /// Batch convert
    func handleBatchConvert() {
        let urls = publicVar.selectedUrls()
        guard !urls.isEmpty else { return }

        BatchConvertPanel.show(urls: urls) { [weak self] in
            self?.scheduledRefresh()
        }
    }
}
