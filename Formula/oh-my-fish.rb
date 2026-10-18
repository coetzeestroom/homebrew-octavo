class OhMyFish < Formula
  desc "Framework for managing your fish shell configuration"
  homepage "https://github.com/oh-my-fish/oh-my-fish"
  url "https://github.com/oh-my-fish/oh-my-fish/archive/refs/tags/v8.tar.gz"
  sha256 "8466063923c38da681d9ab9e6b9d4261a2f62cd856e2e654354f234d74d1f55f"
  license "MIT"
  head "https://github.com/oh-my-fish/oh-my-fish.git", branch: "master"

  depends_on "fish"

  def install
    libexec.install Dir["*"]
  end

  def caveats
    <<~EOS
      Add Oh My Fish to your fish shell by appending to ~/.config/fish/config.fish:

        set -gx OMF_PATH "#{opt_libexec}"
        source $OMF_PATH/init.fish

      Packages and themes installed with `omf install` land in
      $OMF_PATH/pkg, which is inside the brew-managed keg: they are removed
      by `brew upgrade oh-my-fish`. Reinstall your packages after upgrading,
      or install the framework with the upstream installer for a persistent
      setup outside Homebrew's control.

      This formula is not associated with, endorsed by, or affiliated with the
      upstream project. It is created purely for the author's own use. There is
      no expectation of support from the author of this package, nor from the
      authors of the packages referenced herein. Use at your own risk.
    EOS
  end

  test do
    output = shell_output(
      "fish -c 'set -gx OMF_PATH \"#{opt_libexec}\"; " \
      "source $OMF_PATH/init.fish; functions -q omf; and echo OMOK' 2>/dev/null",
    )
    assert_match "OMOK", output
  end
end
