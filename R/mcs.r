#' Monte-Carlo simulation
#'
#' Performs a Monte-Carlo simulation with parameters sampled from a uniform
#' distribution using a latin hypercube method.
#'
#' @param fn Function of interest. It must accept as its first argument
#'   a named numeric vector of parameters. It must return a named numeric vector
#'   (which can be of length 1).
#' @param p Data frame specifying ranges and defaults for the varied parameters.
#'   There must be four columns: 'name', 'default', 'min', and 'max'.
#' @param nRuns Desired number of parameter samples. The total number of
#'   evaluations of \code{fn} is \code{nRuns} + 1.
#' @param silent If \code{TRUE}, diagnostic messages are suppressed.
#' @param ... Additional arguments passed to function \code{fn}.
#'
#' @return A list of 3 elements. Elements \code{p} and \code{out} are matrices
#'   with \code{nRuns} + 1 rows. \code{p} holds the tested parameter values
#'   with column names taken from the 'name' field of \code{ranges}.
#'   \code{out} holds the return values of \code{fn}. Each row in \code{out}
#'   corresponds to the same row of \code{p}. In the common case where \code{fn}
#'   returns a scalar result, \code{out} contains just a single column.
#'   The first row in both data frames corresponds to the default parameter set.
#'   The third list element, \code{cpu} is a vector of length \code{nRuns} + 1,
#'   holding the times spent on the evaluation of \code{fn}.
#'
#' @note If \code{fn} generated an error (or a warning) when called with a
#'   parameter set, the corresponding row in the result matrix \code{out}.
#'   is set to \code{NA}. The same is true for the corresponding element of
#'   the returned vector \code{cpu}.
#'
#' @author David Kneis \email{david.kneis@@tu-dresden.de}
#'
#' @export
#'
#' @examples
#' # Analysis of the residuals' sum of squares for a linear model
#' obs= data.frame(x=c(1,2), y=c(1,2))
#' model= function(p, x) { p["slope"] * x + p["intercept"] }
#' objfun= function(p, obs) { c(sse= sum((obs$y - model(p, obs$x))^2)) }
#' p= data.frame(
#'   name=c("slope","intercept"),
#'   default= c(1, 0),
#'   min= c(0.5, -1),
#'   max= c(2, 1)
#' )
#' x= mcs(fn=objfun, p=p, obs=obs)
#' layout(matrix(1:2, ncol=2))
#' plot(x$p[,"slope"], x$out[,"sse"], xlab="slope", ylab="SSE")
#' plot(x$p[,"intercept"], x$out[,"sse"], xlab="intercept", ylab="SSE")
#' layout(matrix(1))

mcs= function(fn, p, nRuns=10, silent=TRUE, ...) {

  # Check inputs
  if (!is.function(fn))
    stop(paste0("'fn' must be a function"))
  if (!is.data.frame(p))
    stop("'p' must be a data frame")
  required= c("name","default","min","max")
  if (is.null(names(p)) || (!all(required %in% colnames(p))))
    stop(paste0("missing column names in data frame 'p',",
      " expecting '",paste(required,collapse="', '"),"'"))
  if (any(p$max < p$min))
    stop("parameter ranges not reasonable")

  # Sample parameters
  if (!silent)
    print("creating sample")
  prand= improvedLHS(n=nRuns, k=nrow(p))
  colnames(prand)= p$name
  for (i in 1:nrow(p)) {
    prand[,i]= p[i,"min"] + prand[,i] * (p[i,"max"] - p[i,"min"])
  }

  cpu= rep(NA, nRuns + 1)

  # Simulation with defaults to initialize result table
  if (!silent)
    print(paste0("initial run with defaults"))
  t0= Sys.time()
  tmp= fn(setNames(p$default,p$name),...)
  if (!is.numeric(tmp) || is.null(names(tmp)) || (any(names(tmp) == "")))
    stop("'fn' does not return a named numeric vector")
  out= matrix(NA, ncol=length(tmp), nrow=nRuns+1)
  colnames(out)= names(tmp)
  out[1,]= tmp
  t1= Sys.time()
  tTotal= nRuns * as.numeric(difftime(t1, t0, units="secs"))
  tElapsed= 0
  cpu[1]= as.numeric(difftime(t1, t0, units="secs"))

  # Simulations
  for (i in 1:nRuns) {
    if (!silent)
      print(paste0("run ",i," of ",nRuns,", ",(i-1)/nRuns*100,"% done, approx. ",
        round(tTotal-tElapsed,1)," sec. left"))
    t0= Sys.time()
    ok= FALSE
    tryCatch({
      tmp= fn(setNames(prand[i,],colnames(prand)),...)
      out[i+1,]= tmp
      ok= TRUE
    }, error= function(e) {
      print(e)
      out[i+1,]= rep(NA, ncol(out))
    }, warning= function(w) {
      print(w)
      out[i+1,]= rep(NA, ncol(out))
    })
    t1= Sys.time()
    if (ok)
      cpu[i+1]= as.numeric(difftime(t1, t0, units="secs"))
    tElapsed= tElapsed + as.numeric(difftime(t1, t0, units="secs"))
    tTotal= nRuns * tElapsed / i
  }

  # Add default parameters to table of parameters
  prand= rbind(p$default, prand)

  # Return tested parameter values and function results
  return(list(p=prand, out=out, cpu=cpu))
}

