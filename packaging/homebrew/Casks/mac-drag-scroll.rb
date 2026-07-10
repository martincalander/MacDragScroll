cask "mac-drag-scroll" do
  version "1.0.7"
  sha256 "140757c1bb5db0ede2c48e99033528de59e912ce8df830850175bdfabd99bb96"

  url "https://github.com/martincalander/MacDragScroll/releases/download/v#{version}/MacDragScroll.zip"
  name "Mac Drag Scroll"
  desc "Windows-style drag scrolling for external mice"
  homepage "https://github.com/martincalander/MacDragScroll"

  auto_updates true
  depends_on macos: :tahoe

  app "Mac Drag Scroll.app"

  uninstall quit: "com.martincalander.macdragscroll"
end
