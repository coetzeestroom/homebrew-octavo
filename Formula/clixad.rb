class Clixad < Formula
  desc "Free AI coding agent in your terminal, funded by rewarded ads"
  homepage "https://clixad.io/"
  url "https://registry.npmjs.org/clixad/-/clixad-0.0.1-beta.15.tgz"
  version "0.0.1-beta.15"
  sha256 "bb7dcf2b3c712e37406951ca3178bb2186a3a0ea916389437542ddab34cab2e6"
  license "Unlicense"

  depends_on "node@22"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink libexec.glob("bin/*")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/clixad --version")
  end
end
