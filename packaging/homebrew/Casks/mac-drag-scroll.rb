cask "mac-drag-scroll" do
  version "1.5.0"
  sha256 "c47c7baa1082a584a8f540752707ea9da17f6c2d663fb060cdc85f566d66fdf2"

  url "https://github.com/martincalander/MacDragScroll/releases/download/v#{version}/MacDragScroll.zip"
  name "Mac Drag Scroll"
  desc "Windows-style drag scrolling for external mice"
  homepage "https://github.com/martincalander/MacDragScroll"

  auto_updates true
  depends_on macos: :sonoma

  app "Mac Drag Scroll.app"

  uninstall quit: "com.martincalander.macdragscroll"
end
