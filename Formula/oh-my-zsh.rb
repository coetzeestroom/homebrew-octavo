class OhMyZsh < Formula
  desc "Community-driven framework for managing your zsh configuration"
  homepage "https://github.com/ohmyzsh/ohmyzsh"
  url "https://github.com/ohmyzsh/ohmyzsh/archive/964ddf789b022b6958b27d02d7fa54f552de21e9.tar.gz"
  version "2026.10.13.092224"
  sha256 "89ccb57b3328f0df303d557bef54cc7d0efb6f22f016552943ef3e15273e0588"
  license "MIT"
  head "https://github.com/ohmyzsh/ohmyzsh.git", branch: "master"

  # oh-my-zsh never tags releases, so there is no stable version to track:
  # the URL is pinned to a commit and `version` is that commit's date.
  livecheck do
    skip "Project has no tags or releases; version is pinned to the commit date"
  end

  depends_on "zsh"

  def install
    libexec.install Dir["*"]
  end

  def caveats
    <<~EOS
      Add Oh My Zsh to your interactive shell by appending to ~/.zshrc:

        export ZSH="#{opt_libexec}"
        source "$ZSH/oh-my-zsh.sh"

      Oh My Zsh's built-in auto-updater expects a git checkout, which a
      Homebrew install is not. Add this line to ~/.zshrc to disable it and
      update via Homebrew instead (brew upgrade oh-my-zsh):

        export DISABLE_AUTO_UPDATE="true"

      Runtime caches fall back to ~/.cache/oh-my-zsh rather than the
      read-only Cellar keg.

      This formula is not associated with, endorsed by, or affiliated with the
      upstream project. It is created purely for the author's own use. There is
      no expectation of support from the author of this package, nor from the
      authors of the packages referenced herein. Use at your own risk.
    EOS
  end

  test do
    ENV["DISABLE_AUTO_UPDATE"] = "true"
    output = shell_output(
      "zsh --no-rcs -ic 'source #{opt_libexec}/oh-my-zsh.sh; " \
      "print -r -- $ZSH' 2>/dev/null",
    )
    assert_equal opt_libexec.to_s, output.strip
  end
end
