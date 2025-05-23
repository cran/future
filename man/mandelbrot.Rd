% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/demo_api-mandelbrot.R
\name{mandelbrot}
\alias{mandelbrot}
\alias{as.raster.Mandelbrot}
\alias{plot.Mandelbrot}
\alias{mandelbrot_tiles}
\alias{mandelbrot.matrix}
\alias{mandelbrot.numeric}
\title{Mandelbrot convergence counts}
\usage{
mandelbrot(...)

\method{mandelbrot}{matrix}(Z, maxIter = 200L, tau = 2, ...)

\method{mandelbrot}{numeric}(
  xmid = -0.75,
  ymid = 0,
  side = 3,
  resolution = 400L,
  maxIter = 200L,
  tau = 2,
  ...
)
}
\arguments{
\item{Z}{A complex matrix for which convergence
counts should be calculated.}

\item{maxIter}{Maximum number of iterations per bin.}

\item{tau}{A threshold; the radius when calling
divergence (Mod(z) > tau).}

\item{xmid, ymid, side, resolution}{Alternative specification of
the complex plane \code{Z}, where
\code{mean(Re(Z)) == xmid},
\code{mean(Im(Z)) == ymid},
\code{diff(range(Re(Z))) == side},
\code{diff(range(Im(Z))) == side}, and
\code{dim(Z) == c(resolution, resolution)}.}
}
\value{
Returns an integer matrix (of class Mandelbrot) with
non-negative counts.
}
\description{
Mandelbrot convergence counts
}
\examples{
counts <- mandelbrot(xmid = -0.75, ymid = 0, side = 3)
str(counts)
\dontrun{
plot(counts)
}

\dontrun{
demo("mandelbrot", package = "future", ask = FALSE)
}

}
\author{
The internal Mandelbrot algorithm was inspired by and
adopted from similar GPL code of Martin Maechler available
from ftp://stat.ethz.ch/U/maechler/R/ on 2005-02-18 (sic!).
}
\keyword{internal}
