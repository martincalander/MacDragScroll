cask "mac-drag-scroll" do
  version "1.2.0"
  sha256 "f98729233becb3aa1c4a253e509bebf86eeac3a835d6ec2c8319f4f1a1fef9d6"

  url "https://github.com/martincalander/MacDragScroll/releases/download/v#{version}/MacDragScroll.zip"
  name "Mac Drag Scroll"
  desc "Windows-style drag scrolling for external mice"
  homepage "https://github.com/martincalander/MacDragScroll"

  auto_updates true
  depends_on macos: :sonoma

  app "Mac Drag Scroll.app"

  uninstall quit: "com.martincalander.macdragscroll"
end
