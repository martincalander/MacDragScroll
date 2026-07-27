cask "mac-drag-scroll" do
  version "1.3.0"
  sha256 "baf0c2e8324755bf7fed4bc2a31e145c5e67bd00cc83e6a581fe09dc7611c2af"

  url "https://github.com/martincalander/MacDragScroll/releases/download/v#{version}/MacDragScroll.zip"
  name "Mac Drag Scroll"
  desc "Windows-style drag scrolling for external mice"
  homepage "https://github.com/martincalander/MacDragScroll"

  auto_updates true
  depends_on macos: :sonoma

  app "Mac Drag Scroll.app"

  uninstall quit: "com.martincalander.macdragscroll"
end
