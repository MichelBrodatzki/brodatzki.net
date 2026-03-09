# Custom ShareLatex image
FROM sharelatex/sharelatex:5.5.7
# Install inkscape for svg package
RUN apt update; apt install --yes inkscape
# Update texlive manager and install available packages
RUN /usr/local/texlive/2025/bin/x86_64-linux/tlmgr option repository https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2025/tlnet-final/; /usr/local/texlive/2025/bin/x86_64-linux/tlmgr update --self; /usr/local/texlive/2025/bin/x86_64-linux/tlmgr install scheme-full; exit 0
# Add texlive folder to tlmgr path
RUN cd /usr/local/texlive/2025/bin/x86_64-linux/; tlmgr path add
