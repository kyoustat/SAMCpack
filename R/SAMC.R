#' Stochastic Approximation Monte Carlo (SAMC) Sampler
#' 
#' The function \code{SAMC} is a generic SAMC sampler for distributions on continuous domain. An \eqn{R} function for 
#' negative log density of your choice is required, as well as some parameters in SAMC framework.
#' 
#' @param nv number of variables.
#' @param energy an \code{R} function for negative log density.
#' @param options a list specifying parameters/options for SAMC algorithm. Below, vector(\eqn{k}) means a vector of length \eqn{k}, and matrix likewise.
#' \tabular{lll}{
#' PARAMETER        \tab SPECIFICATION \tab DESCRIPTION \cr
#' \code{domain}    \tab vector(\eqn{2}) or matrix(\eqn{(nv\times 2)}) \tab domain of sample space \cr
#' \code{partition} \tab vector(\eqn{m}) \tab energy partition \cr
#' \code{vecpi}     \tab vector(\eqn{m-1}) \tab desired sampling distribution \cr
#' \code{tau}       \tab positive number \tab temperature \cr
#' \code{niter}     \tab positive integer \tab number of iterations to be run \cr
#' \code{t0}        \tab \eqn{(0.5,1]}  \tab gain factor sequence value \cr
#' \code{xi}        \tab positive number \tab gain factor sequence exponent \cr
#' \code{stepsize}  \tab positive number \tab stepsize for random-walk sampler \cr
#' \code{trange}    \tab vector(\eqn{2}) or matrix(\eqn{m\times 2}) \tab domain of estimates for \eqn{\log(g_i /\pi_i)}
#' }
#' 
#' @return a named list containing \describe{
#' \item{samples}{an \eqn{(niter\times nv)} samples generated.}
#' \item{frequency}{length-\eqn{m} vector of visiting frequency for energy partition.}
#' \item{theta}{length-\eqn{m} vector of estimates of \eqn{\log(g_i / \pi_i)}}
#' }
#' 
#' 
#' @examples
#' ##### Two-Dimensional Multimodal sampling
#' ## Step 1 : Define negative log-density function as an R function
#' func_r = function(x){
#' x1 = x[1]; x2 = x[2];
#' val1 = (-(x1*sin(20*x2)+x2*sin(20*x1))^2)*cosh(sin(10*x1)*x1);
#' val2 = (-(x1*cos(10*x2)-x2*sin(10*x1))^2)*cosh(cos(20*x2)*x2);
#' return(val1+val2);
#' }
#' 
#' ## Step 2 : Prepare a setting option
#' myoption = list()
#' myoption$partition = c(-Inf,seq(from=-8,to=0,length.out=41))
#' myoption$tau       = 1.0
#' myoption$domain    = c(-1.1,1.1)
#' myoption$vecpi     = as.vector(rep(1/41,41))
#' myoption$niter     = 20000
#' myoption$stepsize  = c(0.25, 10)
#' 
#' ## Step 3 : Run The Code
#' res = SAMC(2,func_r,options=myoption)
#' 
#' ## Step 4 : Visualize
#' select = seq(from=101,to=myoption$niter,by=100) # 100 burn-in, 1/100 thinning 
#' opar <- par(no.readonly=TRUE)
#' par(mfrow=c(1,2))
#' plot(res$samples[select,1], res$samples[select,2],
#'      xlab='x',ylab='y',main='samples', cex=0.9, type="b")
#' barplot(as.vector(res$frequency/sum(res$frequency)),
#'         main="visiting frequency by energy partition",
#'         names.arg=myoption$partition[-1], xlab="energy")
#' par(opar)
#' 
#' @references 
#' \insertRef{SAMC}{SAMCpack}
#' 
#' @author Kisung You
#' @export
SAMC <- function(nv,energy,options=list()){
  ##-------------------------------------------------------------------
  # PREPROCESSING
  #   1. (int)     nv        : number of variables
  #   2. (func)    energy    : function 
  #   3. (vec/mat) domain    : for samples to reside (nv-by-2) or length-2 vector
  #   3. (vec)     partition : energy-level partition for dividing the sample space into partitions (m+1)
  #   4. (vec)     vecpi     : desired sampling distribution (m)
  #   5. (double)  tau       : temperature
  #   6. (int)     niter     : number of iterations for sampling
  #   7. (double)  t0       : gain factor sequence
  #   8. (double)  xi       : gain factor exponent
  #   9. (num/vec)  stepsize : normal proposal
  #  10. (vec/mat) trange   : theta space of (m-by-2)
  
  if (!is.function(energy)){ stop("* SAMC : 'energy' must be a function.")  }
  if (!is.list(options)){    stop("* SAMC : 'options' must be a list.")     }
  
  pruned    = optionlist(options,nv,"SAMC")
  domain    = pruned$domain
  partition = pruned$partition
  vecpi     = pruned$vecpi
  tau       = pruned$tau
  niter     = pruned$niter
  t0        = pruned$t0
  xi        = pruned$xi
  stepsize  = pruned$stepsize
  trange    = pruned$trange
  m         = pruned$m  # added for fun
  
  # parnames = names(options)
  # if (!("domain" %in% parnames)){    domain = c(-Inf,Inf)  } else {domain=options$domain}
  # if (!("partition" %in% parnames)){ partition = seq(-1e+2,1e+2,length.out=9)} else {partition=options$partition}
  # if (!("vecpi" %in% parnames)){     vecpi=rep(1/10,10)} else {vecpi=options$vecpi}
  # if (!("tau" %in% parnames)){       tau=1.0} else {tau=options$tau}
  # if (!("niter" %in% parnames)){     niter=20000} else {niter=options$niter}
  # if (!("t0" %in% parnames)){        t0=200} else {t0=options$t0}
  # if (!("xi" %in% parnames)){        xi=2/3} else {xi=options$xi}
  # if (!("stepsize" %in% parnames)){  stepsize=1.0} else {stepsize=options$stepsize}
  # if (!("trange" %in% parnames)){    trange=c(-Inf,Inf)} else {trange=options$trange}
  # 
  # 
  # 
  # 
  # if ((length(nv)>1)||(!is.numeric(nv))||(nv<1)||(is.infinite(nv))||(is.na(nv))){
  #   stop("* SAMC : 'nv' should be a positive integer.")
  # }
  # nv = as.integer(nv)
  # if (!is.function(energy)){
  #   stop("* SAMC : 'energy' must be a function.")
  # }
  # if (is.vector(domain)){
  #   if ((length(domain)!=2)||(any(!is.numeric(domain)))||(any(is.na(domain)))){
  #     stop("* SAMC : 'domain' should be a vector of length 2.")
  #   }
  #   domain = matrix(sort(domain),nrow=nv,ncol=length(domain),byrow=TRUE)
  # } else if (is.matrix(domain)){
  #   if ((dim(domain)[1]!=nv)||(dim(domain)[2]!=2)||(any(is.na(domain)))||(any(!is.numeric(domain)))){
  #     stop("* SAMC : 'domain' should be a matrix of size (nv-by-2).")
  #   }
  #   for (i in 1:nv){
  #     domain[i,] = sort(domain[i,])
  #   }
  # } else {
  #   stop("* SAMC : 'domain' should be either a vector or a matrix.")
  # }
  # if (any(is.infinite(domain))){
  #   message("* SAMC : 'domain' would be better without infinite values.")
  #   message("*      : automatically replacing Inf's with suitably large numbers.")
  #   domain = adjust_inf(domain)
  # }
  # if ((!is.vector(partition))||(length(partition)<2)||(any(!is.numeric(partition)))){
  #   stop("* SAMC : 'energy' should be a vector whose length is greater than 1.")
  # }
  # partition = as.vector(sort(partition))
  # if ((any(is.null(vecpi)))||(length(vecpi)!=(length(partition)-1))||(any(vecpi<=0))||(abs(sum(vecpi)-1)>1e-10)){
  #   stop("* SAMC : desired sampling distribution 'vecpi' is invalid.")
  # }
  # vecpi = as.vector(sort(vecpi))
  # tau = as.double(tau)
  # if ((!is.numeric(niter))||(niter<=1)||(is.infinite(niter))||(is.na(niter))||(length(niter)>1)){
  #   stop("* SAMC : 'niter' should be a positive integer as an iteration number.")
  # }
  # t0 = as.double(t0)
  # if ((!is.numeric(xi))||(xi<=0.5)||(xi>1)||(length(xi)>1)||(is.null(xi))){
  #   stop("* SAMC : 'xi' should be in (0.5,1].")
  # }
  # xi = as.double(xi)
  # if ((!is.numeric(stepsize))||(stepsize<=0)||(is.infinite(stepsize))||(length(stepsize)>1)){
  #   stop("* SAMC : 'stepsize' is a standard deviation term for normal proposal density")
  # }
  # stepsize = as.double(stepsize)
  # m = length(vecpi)
  # if (is.vector(trange)){
  #   if ((length(trange)!=2)||(any(!is.numeric(trange)))||(any(is.na(trange)))){
  #     stop("* SAMC : 'trange' should be a vector of length 2.")
  #   }
  #   trange = matrix(sort(trange),nrow=m,ncol=length(trange),byrow=TRUE)
  # } else if (is.matrix(trange)){
  #   if ((dim(trange)[1]!=m)||(dim(trange)[2]!=2)||(any(is.na(trange)))||(any(!is.numeric(trange)))){
  #     stop("* SAMC : 'trange' should be a matrix of size (m-by-2).")
  #   }
  #   for (i in 1:m){
  #     trange[i,] = sort(trange[i,])
  #   }
  # } else {
  #   stop("* SAMC : 'trange' should be either a vector or a matrix.")
  # }

  ##-------------------------------------------------------------------
  # INITIALIZATION
  init = array(0,nv)
  for (i in 1:nv){
    subdomain = domain[i,]
    if (is.infinite(subdomain[1])){
      if (is.infinite(subdomain[2])){
        init[i] = 0
      }else{
        init[i] = runif(1,subdomain[2]-10,subdomain[2])
      }
    } else{
      if (is.infinite(subdomain[2])){
        init[i] = runif(1,subdomain[1],subdomain[1]+10)
      }else{
        init[i] = (subdomain[1]+subdomain[2])/2
      }
    }
  }
  
  ##-------------------------------------------------------------------
  # MAIN COMPUTATION
  output = exec_SAMC(energy,nv,partition,domain,tau,niter,vecpi,t0,xi,stepsize,trange,init)
  
  ##-------------------------------------------------------------------
  # END
  return(output)
}


# 
# func_r = function(x){
# x1 = x[1]; x2 = x[2];
# val1 = (-(x1*sin(20*x2)+x2*sin(20*x1))^2)*cosh(sin(10*x1)*x1);
# val2 = (-(x1*cos(10*x2)-x2*sin(10*x1))^2)*cosh(cos(20*x2)*x2);
# return(val1+val2);
# }
# ex_energy = c(-Inf,seq(from=-8,to=0,by=0.2))
# m         = length(ex_energy)-1
# ex_temp   = 1.0
# ex_step   = (0.25)
# ex_vecpi  = as.vector(array(1/m,c(1,m)))
# ex_domain = c(-1.1,1.1)
# ex_niter  = 200000
# res1 = SAMC(2,func_r,partition=ex_energy,tau=ex_temp,stepsize=ex_step,vecpi=ex_vecpi,domain=ex_domain,niter=ex_niter)
