library(lhs)
library(laGP)

# 6.2 SEQUENTIAL DESIGN ---------------------------------------------------

# Generate design

ninit <- 12

X <- randomLHS(ninit, 2)

f <- function(X, sd=0.01) 
{
        X[,1] <- (X[,1] - 0.5)*6 + 1
        X[,2] <- (X[,2] - 0.5)*6 + 1
        y <- X[,1] * exp(-X[,1]^2 - X[,2]^2) + rnorm(nrow(X), sd=sd)
}

y <- f(X)

# Initial model fitting

g <- garg(list(mle = TRUE, max = 1), y)

d <- darg(list(mle = TRUE, max = 0.25), X)

gpi <- newGP(X, y, d = d$start, g = g$start, dK = T)

mle <- jmleGP(gpi, c(d$min, d$max), c(g$min, g$max), d$ab, g$ab)

# Test grid

x1 <- x2 <- seq(0, 1, length = 100)

XX <- expand.grid(x1, x2)

yytrue <- f(XX, sd = 0)

rmse <- sqrt(mean((yytrue - predGP(gpi, XX, lite=TRUE)$mean)^2))

# Determine where is the maximum variance

obj.alm <- function(x, gpi){
        - sqrt(predGP(gpi, matrix(x, nrow=1), lite=TRUE)$s2)
}

xnp1.search <- function(X, gpi, obj=obj.alm, ...)
{
        start <- mymaximin(nrow(X), 2, T=100*nrow(X), Xorig=X)
        xnew <- matrix(NA, nrow=nrow(start), ncol=ncol(X) + 1)
        for(i in 1:nrow(start)) {
                out <- optim(start[i,], obj, method="L-BFGS-B", lower=0, 
                             upper=1, gpi=gpi, ...)
                xnew[i,] <- c(out$par, -out$value)
        }
        solns <- data.frame(cbind(start, xnew))
        names(solns) <- c("s1", "s2", "x1", "x2", "val")
        return(solns)
}


mymaximin <- function(n, m, T=100000, Xorig=NULL) 
{   
        X <- matrix(runif(n*m), ncol=m)     ## initial design
        d <- distance(X)
        d <- d[upper.tri(d)]
        md <- min(d)
        if(!is.null(Xorig)) {               ## new code
                md2 <- min(distance(X, Xorig))
                if(md2 < md) md <- md2
        }
        
        for(t in 1:T) {
                row <- sample(1:n, 1)
                xold <- X[row,]                   ## random row selection
                X[row,] <- runif(m)               ## random new row
                d <- distance(X)
                d <- d[upper.tri(d)]
                mdprime <- min(d)
                if(!is.null(Xorig)) {             ## new code
                        mdprime2 <- min(distance(X, Xorig))
                        if(mdprime2 < mdprime) mdprime <- mdprime2
                }
                if(mdprime > md) { md <- mdprime  ## accept
                } else { X[row,] <- xold }        ## reject
        }
        
        return(X)
}

solns <- xnp1.search(X, gpi)

plot(X, xlab="x1", ylab="x2", xlim=c(0,1), ylim=c(0,1))

arrows(solns$s1, solns$s2, solns$x1, solns$x2, length=0.1)

m <- which.max(solns$val)

prog <- solns$val[m]

points(solns$x1[m], solns$x2[m], col=2, pch=20)

xnew <- as.matrix(solns[m, 3:4])

X <- rbind(X, xnew)

y <- c(y, f(xnew))

updateGP(gpi, xnew, y[length(y)])

mle <- rbind(mle, jmleGP(gpi, c(d$min, d$max), c(g$min, g$max), 
                         d$ab, g$ab))

rmse <- c(rmse, sqrt(mean((yytrue - predGP(gpi, XX, lite=TRUE)$mean)^2)))

solns <- xnp1.search(X, gpi)
m <- which.max(solns$val)
prog <- c(prog, solns$val[m])
xnew <- as.matrix(solns[m, 3:4])
X <- rbind(X, xnew)
y <- c(y, f(xnew))
updateGP(gpi, xnew, y[length(y)])
mle <- rbind(mle, jmleGP(gpi, c(d$min, d$max), c(g$min, g$max), 
                         d$ab, g$ab))
p <- predGP(gpi, XX, lite=TRUE)
rmse <- c(rmse, sqrt(mean((yytrue - p$mean)^2)))

plot(X, xlab="x1", ylab="x2", xlim=c(0,1), ylim=c(0,1))
arrows(solns$s1, solns$s2, solns$x1, solns$x2, length=0.1)
m <- which.max(solns$val)
points(solns$x1[m], solns$x2[m], col=2, pch=20)

# Active learning Cohn