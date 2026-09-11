class OhMyZsh < Formula
  desc "Community-driven framework for managing your zsh configuration"
  homepage "https://github.com/ohmyzsh/ohmyzsh"
  url "https://github.com/ohmyzsh/ohmyzsh/archive/c6e66edee824d83e84473ec666917b58323630df.tar.gz"
  version "2026-09-10"
  sha256 "200d79c1fa0784107cd897db96c7823ecae4cec332026a7f4471568fc59db519"
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
