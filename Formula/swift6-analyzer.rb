class Swift6Analyzer < Formula
  desc "CLI tool that scans Swift codebases for Swift 6 concurrency migration issues"
  homepage "https://github.com/Maetschl/Swift6-migration"
  version "1.2.0"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Maetschl/Swift6-migration/releases/download/1.2.0/swift6-analyzer-1.2.0-macos.zip"
      # sha256 will be filled in when the release is published
      sha256 "PLACEHOLDER_SHA256"
    else
      url "https://github.com/Maetschl/Swift6-migration/releases/download/1.2.0/swift6-analyzer-1.2.0-macos.zip"
      sha256 "PLACEHOLDER_SHA256"
    end
  end

  def install
    bin.install "swift6-analyzer"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/swift6-analyzer --version")
  end
end
