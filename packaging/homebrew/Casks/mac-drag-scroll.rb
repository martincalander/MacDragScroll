cask "mac-drag-scroll" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/martincalander/MacDragScroll/releases/download/v#{version}/MacDragScroll.zip"
  name "Mac Drag Scroll"
  desc "Windows-style drag scrolling for external mice on macOS"
  homepage "https://github.com/martincalander/MacDragScroll"

  auto_updates true
  depends_on macos: ">= :tahoe"

  app "Mac Drag Scroll.app"

  uninstall quit: "com.martincalander.macdragscroll"
end
