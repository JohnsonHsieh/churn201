library(ggplot2)
library(gridExtra)
library(scales)
library(manipulate)

gpal <- scales::hue_pal(h = c(0, 360) + 15, c = 100, l = 65, h.start = 0, direction=1)(8)

# set up my defaults in a global list
def <- list()
def$max.benefit <- 0.5
def$cost.ramp <- 3.5
def$cost.scale <- 2
def$salary <- 0.5
def$shape.good <- 2.5
def$scale.good <- 1.5
def$shape.bad <- 1.66
def$scale.bad <- 0.33
def$good.bad.ratio <- 0.6
def$max.yrs <- 3
def$col.benefit <- gpal[3]	# dark green
def$col.cost <- gpal[1]		# salmon
def$col.good <- gpal[5]		# blue-grey
def$col.bad <- gpal[2]		# brown
def$col.be <- "DarkGray"
def$col.be.cume <- "DarkGray"


# run the sim with manipulators
manipSim202 <- function() {
	manipulate(runSim202(max.yrs, max.benefit, 
						 cost.ramp, cost.scale, salary,
						 shape.good, scale.good, shape.bad, scale.bad, 
						 good.bad.ratio),
			   good.bad.ratio = slider(0.0, 1, initial=def$good.bad.ratio),
			   shape.good = slider(1.01, 5, initial=def$shape.good), 
			   scale.good = slider(0.01, 5, initial=def$scale.good), 
			   shape.bad = slider(1.01, 5, initial=def$shape.bad), 
			   scale.bad = slider(0.01, 5, initial=def$scale.bad), 
			   max.benefit = slider(0.25, 3, initial =def$max.benefit),
			   cost.ramp = slider(0.5, 5, initial=def$cost.ramp), 
			   cost.scale = slider(0.5, 5, initial=def$cost.scale), 
			   salary = slider(0.0, 1, initial=def$salary),
			   max.yrs = slider(1, 8, initial=def$max.yrs))
}

# run the sim, return the plots and print out cume info
runSim202 <- function(max.yrs=def$max.yrs, max.benefit=def$max.benefit, 
					  cost.ramp=def$cost.ramp, cost.scale=def$cost.scale, salary=def$salary,
					  shape.good=def$shape.good, scale.good=def$scale.good, 
					  shape.bad=def$shape.bad, scale.bad=def$scale.bad, 
					  good.bad.ratio=def$good.bad.ratio,
					  do.annotate=FALSE,
					  list.plots=FALSE) {

	# divide our years uniformly, 100 pts a year
	dist.year <- as.data.frame( 0:(max.yrs*100)/100 )
	names(dist.year) <- "tenure"
	dist.year$benefit <- empBenefit(dist.year$tenure, max.benefit)
	dist.year$benefit.cume <- empBenefitCume(dist.year$tenure, max.benefit)
	dist.year$cost <- empCost(dist.year$tenure, cost.ramp, cost.scale, salary)
	dist.year$cost.cume <- empCostCume(dist.year$tenure, cost.ramp, cost.scale, salary)
	dist.year$prob.good <- dweibull(dist.year$tenure, shape=shape.good, scale=scale.good)
	dist.year$prob.bad <- dweibull(dist.year$tenure, shape=shape.bad, scale=scale.bad)
	dist.year$prob.good.wt <- dist.year$prob.good * good.bad.ratio
	dist.year$prob.bad.wt <- dist.year$prob.bad * (1-good.bad.ratio)

	# TODO C: could solve for breakeven point in another way, to handle off-chart cases, 
	#         but in that case, they would be off the chart.... so who cares.

	# calc breakeven points
	be.pt.id <- which.max(dist.year$benefit - dist.year$cost>0)
	be.pt <- dist.year$tenure[be.pt.id]
	be.cume.id <- which.max(dist.year$benefit.cume - dist.year$cost.cume>0)
	be.cume <- dist.year$tenure[be.cume.id]

	writeLines(sprintf("Daily breakeven at %.2f, cume breakeven at %.2f", be.pt, be.cume))

	evh <- runPredNetCume(max.benefit, cost.ramp, cost.scale, salary,
				  shape.good, scale.good, shape.bad, scale.bad, 
				  good.bad.ratio, verbose=TRUE)

	gglist <- list()

	gglist$fig4 <- suppressWarnings(ggplot(data=dist.year, aes(x=tenure)) + 
									 geom_vline(xintercept=be.pt, col=def$col.be, size=0.5, linetype="dashed") +
									 geom_vline(xintercept=be.cume, col=def$col.be.cume, size=0.5, linetype="dashed") +
									 geom_line(aes(y=prob.bad), col=def$col.bad, size=1) +
									 geom_line(aes(y=prob.good), col=def$col.good, size=1) +
									 scale_y_continuous(labels = percent) +
									 theme_bw() +
									 theme(text = element_text(size=8), 
										   axis.title.y = element_text(size=8)) +
									 xlim(c(0,max.yrs)) +
									 labs(title="Probability of Employee Termination", 
										  x="Tenure in Years", 
										  y="Probability"))

	if (do.annotate) {
		gglist$fig4 <- gglist$fig4 +
						annotate("text", 
								 x=1.75, y=0.7, hjust=0, vjust=1,
								 color=def$col.good,
								 label="Good Fit") +
						annotate("text", 
							 x=0.5, y=2, hjust=0, vjust=1,
							 color=def$col.bad,
							 label="Bad Fit")
	}

	gglist$fig5 <- suppressWarnings(ggplot(data=dist.year, aes(x=tenure)) + 
									 geom_vline(xintercept=be.pt, col=def$col.be, size=0.5, linetype="dashed") +
									 geom_vline(xintercept=be.cume, col=def$col.be.cume, size=0.5, linetype="dashed") +
									 geom_ribbon(fill=def$col.cost, size=0, aes(ymax=cost,ymin=benefit,alpha=cost>benefit)) + 
									 scale_alpha_discrete(range=c(0,.25)) + 
									 theme(legend.position="none") +
									 geom_line(col=def$col.cost, size=1, aes(y=cost)) + 
									 geom_line(col=def$col.benefit, size=1, aes(y=benefit)) +
									 scale_y_continuous(labels = percent) +
									 theme_bw() +
									 theme(text = element_text(size=8), 
										   axis.title.y = element_text(size=8)) +
									 theme(legend.position="none") +
									 labs(title="Benefit & Cost of One Employee", 
										  x="Tenure in Years", 
										  y="% Potential Value"))
	if (do.annotate) {
		gglist$fig5 <- gglist$fig5 +
						 annotate("text", 
								  x=1.75, y=1, hjust=0, vjust=-0.2,
								  color=def$col.benefit,
								  label="Benefit") +
						 annotate("text", 
								  x=1.75, y=0.5, hjust=0, vjust=-0.2,
								  color=def$col.cost,
								  label="Cost") +
						 annotate("text", 
								  x=be.pt, y=0.1, hjust=-0.1, vjust=0,
								  color=def$col.be,
								  label="B/E") +
						 annotate("text", 
								  x=be.cume, y=0.1, hjust=-0.1, vjust=0,
								  color=def$col.be,
								  label="B/E Cume") 
	}

	gglist$fig6 <- suppressWarnings(ggplot(data=dist.year, aes(x=tenure)) + 
									 geom_vline(xintercept=be.pt, col=def$col.be, size=0.5, linetype="dashed") +
									 geom_vline(xintercept=be.cume, col=def$col.be.cume, size=0.5, linetype="dashed") +
									 geom_hline(yintercept=0, col=def$col.be.cume, size=0.5, linetype="dotted") +
									 geom_ribbon(size=0, alpha=0.5, ymin=0,
												 aes(ymax=(benefit.cume-cost.cume), 
													 fill=(benefit.cume-cost.cume)>0)) + 
									 geom_line(size=1, 
											   aes(y=(benefit.cume-cost.cume),
												   col=(benefit.cume-cost.cume)>0)) +
									 scale_y_continuous(labels = percent) +
									 scale_fill_manual(values=c(def$col.cost, def$col.benefit)) +
									 scale_color_manual(values=c(def$col.cost, def$col.benefit)) +
									 theme_bw() +
									 theme(text = element_text(size=8), 
										   axis.title.y = element_text(size=8)) +
									 theme(legend.position="none") +
									 xlim(c(0,max.yrs)) +
									 labs(title="Cumulative Net Benefit", 
										  x="Tenure in Years", 
										  y="Cumulative Net Benefit"))
	if (do.annotate) {
		gglist$fig6 <- gglist$fig6 +
						 annotate("text", 
								  x=2, y=-0.1, hjust=0.5, vjust=0,
								  color=def$col.benefit,
								  label="Net Benefit") +
						 annotate("text", 
								  x=0.3, y=0.1, hjust=0.5, vjust=1,
								  color=def$col.cost,
								  label="Net Cost") +
						 annotate("text", 
								  x=be.pt, y=0.90, hjust=-0.1, vjust=0,
								  color=def$col.be,
								  label="B/E") +
						 annotate("text", 
								  x=be.cume, y=0.90, hjust=-0.1, vjust=0,
								  color=def$col.be,
								  label="B/E Cume")
	}

	gglist$fig7 <- suppressWarnings(ggplot(data=dist.year, aes(x=tenure)) + 
									 geom_vline(xintercept=be.pt, col=def$col.be, size=0.5, linetype="dashed") +
									 geom_vline(xintercept=be.cume, col=def$col.be.cume, size=0.5, linetype="dashed") +
									 geom_hline(yintercept=0, col=def$col.be.cume, size=0.5, linetype="dotted") +
									 geom_ribbon(fill=def$col.bad, size=0, alpha=0.5, ymin=0,
												 aes(ymax=(benefit.cume-cost.cume)*prob.bad.wt)) + 
									 geom_line(aes(y=(benefit.cume-cost.cume)*prob.bad.wt), col=def$col.bad, size=1) +
									 geom_ribbon(fill=def$col.good, size=0, alpha=0.5, ymin=0,
												 aes(ymax=(benefit.cume-cost.cume)*prob.good.wt)) + 
									 geom_line(aes(y=(benefit.cume-cost.cume)*prob.good.wt), col=def$col.good, size=1) +
									 annotate("text", 
											  x=1.5, y=-0.1, hjust=0, vjust=0,
											  size=4,
											  color=ifelse(evh<0,def$col.cost,def$col.benefit),
											  label=sprintf("EVH = %.1f%%",evh*100)) +
									 scale_y_continuous(labels = percent) +
									 theme_bw() +
									 theme(text = element_text(size=8), 
										   axis.title.y = element_text(size=8)) +
									 xlim(c(0,max.yrs)) +
									 labs(title="Expected Cumulative Net Benefit", 
										  x="Tenure in Years", 
										  y="Cumulative Net Benefit\nx Probability"))

	if (do.annotate) {
		gglist$fig7 <- gglist$fig7 +
						 annotate("text", 
								  x=1.5, y=0, hjust=0, vjust=1.5,
								  color=def$col.good,
								  label="Good Fit") +
						 annotate("text", 
								  x=0.45, y=-0.15, hjust=0, vjust=0,
								  color=def$col.bad,
								  label="Bad Fit")
	}

	fig45 <- arrangeGrob(gglist$fig4, gglist$fig5, main="Employee Tenure, Benefit, and Costs", ncol=1)
	fig67 <- arrangeGrob(gglist$fig6, gglist$fig7, main="Employee Cumulative Net Benefit", ncol=1)
	fig4567 <- arrangeGrob(fig45, fig67, ncol=2)

	if (list.plots) {
		return(gglist)
	} else {
		return(fig4567)
	}

}

# vector-friendly benefit from employee, modeled as a sigmoid function
empBenefit <- function(tenure, max.benefit) {
	1/(1+exp(-(tenure/max.benefit*12-6)))
}

# vector friendly cumulative benefit, the integral of empBenefit
empBenefitCume <- function(tenure, max.benefit) {
	# use sapply to make integrate vector-friendly
	sapply(tenure, function(x) { integrate(empBenefit, 0, x, 
										   max.benefit=max.benefit)$value })
}

# vector-friendly cost of employee, modeled as a gompertz function
empCost <- function(tenure, cost.ramp, cost.scale, salary) {
	exp(-exp(cost.ramp * tenure)) * cost.scale + salary
}

# vector friendly cumulative cost, the integral of empCost
empCostCume <- function(tenure, cost.ramp, cost.scale, salary) {
	# use sapply to make integrate vector-friendly
	sapply(tenure, function(x) { integrate(empCost, 0, x, 
										   cost.ramp=cost.ramp, 
										   cost.scale=cost.scale, 
										   salary=salary)$value })
}

# one function for one tenure moment, for use by empPredNetCume and graphing
empPredNet <- function(tenure, 
					   max.yrs, max.benefit, 
					   cost.ramp, cost.scale, salary,
					   d.shape, d.scale) {

	# net = benefit - cost
	z.net <- empBenefit(tenure, max.benefit) - empCost(tenure, cost.ramp, cost.scale, salary)

	# weighted by probability of that tenure position
	z.prob <- dweibull(tenure, shape=d.shape, scale=d.scale)

	return(z.net * z.prob)
}

# the sum of all net benefits given these settings
empPredNetCume <- function(max.benefit, 
						   cost.ramp, cost.scale, salary, 
						   d.shape, d.scale) {
	# hacked the 0.01 instead of 0 here to avoid error on super-high prob low value events
	integrate(empPredNet, 0.01, Inf,
			  max.benefit=max.benefit,
			  cost.ramp=cost.ramp, 
			  cost.scale=cost.scale, 
			  salary=salary,
			  d.shape=d.shape,
			  d.scale=d.scale
			  )$value
}

# run the sim for just the cume value, maybe print out values, return cume
runPredNetCume <- function(max.benefit = def$max.benefit, 
						  cost.ramp = def$cost.ramp, cost.scale = def$cost.scale, salary = def$salary,
						  shape.good = def$shape.good, scale.good = def$scale.good, 
						  shape.bad = def$shape.bad, scale.bad = def$scale.bad,
						  good.bad.ratio = def$good.bad.ratio,
						  verbose=FALSE) {

	# if (verbose) {
	# 	writeLines(sprintf("Sim for max.benefit = %.2f, cost.ramp = %.2f, cost.scale = %.2f, salary = %.2f",
	# 					   max.benefit, cost.ramp, cost.scale, salary))
	# 	writeLines(sprintf("  shape.good = %.2f, scale.good = %.2f, shape.bad = %.2f, scale.bad = %.2f",
	# 					   shape.good, scale.good, shape.bad, scale.bad))
	# 	writeLines(sprintf("  good.bad.ratio = %.2f", good.bad.ratio))
	# }

	cume.good <- empPredNetCume(max.benefit, cost.ramp, cost.scale, salary, shape.good, scale.good)
	cume.bad <- empPredNetCume(max.benefit, cost.ramp, cost.scale, salary, shape.bad, scale.bad)

	cume.good.wt <- cume.good * good.bad.ratio 
	cume.bad.wt <- cume.bad * (1-good.bad.ratio)

	cume.total <- cume.good.wt + cume.bad.wt

	if (verbose) {
		writeLines(sprintf("Good Fit: %.1f%% net benefit * %.0f%% weight = %.1f%% overall contribution",
						   cume.good * 100, good.bad.ratio * 100, cume.good.wt * 100))
		writeLines(sprintf("Bad Fit: %.1f%% net benefit * %.0f%% weight = %.1f%% overall contribution",
						   cume.bad * 100, (1-good.bad.ratio) * 100, cume.bad.wt * 100))
		writeLines(sprintf("Overall EVH = %.1f%%", cume.total * 100))

		# TODO: better printout, compare to salary
	}

	return(cume.total)
}

# modify one variable through its range to calc sensitivity
# limited analysis - just based on the "reasonable" starting point
runSensitivityTests <- function() {
	writeLines("Running Sensitivity Tests")

	# modify good.bad.ratio from 0-1 from base of 0.3
	writeLines(sprintf("  good.bad.ratio:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$good.bad.ratio, 
					   (runPredNetCume(good.bad.ratio=def$good.bad.ratio*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0, 1, 0.05)
	g.gbr <- sensitivityPlot("Good.Bad.Ratio", def$good.bad.ratio, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(good.bad.ratio=x)}))

	# modify shape.good from 1-5 from base of 2.5 
	writeLines(sprintf("  shape.good:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$shape.good, 
					   (runPredNetCume(shape.good=def$shape.good*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(1, 5, 0.05)
	g.shg <- sensitivityPlot("Shape.Good", def$shape.good, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(shape.good=x)}))

	# modify scale.good from 0.01-5 from base of 1.5 
	writeLines(sprintf("  scale.good:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$scale.good, 
					   (runPredNetCume(scale.good=def$scale.good*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0.01, 5, 0.05)
	g.scg <- sensitivityPlot("Scale.Good", def$scale.good, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(scale.good=x)}))

	# modify shape.bad from 1-5 from base of 1.66 
	writeLines(sprintf("  shape.bad:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$shape.bad, 
					   (runPredNetCume(shape.bad=def$shape.bad*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(1, 5, 0.05)
	g.shb <- sensitivityPlot("Shape.Bad", def$shape.bad, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(shape.bad=x)}))

	# modify scale.bad from 0.01-5 from base of 0.33 
	writeLines(sprintf("  scale.bad:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$scale.bad, 
					   (runPredNetCume(scale.bad=def$scale.bad*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0.01, 5, 0.05)
	g.scb <- sensitivityPlot("Scale.Bad", def$scale.bad, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(scale.bad=x)}))

	# modify max.benefit from 0.25-3, initial = 0.5
	writeLines(sprintf("  max.benefit:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$max.benefit, 
					   (runPredNetCume(max.benefit=def$max.benefit*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0.25, 3, 0.05)
	g.mb <- sensitivityPlot("Max.Benefit", def$max.benefit, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(max.benefit=x)}))

	# modify cost.ramp from 0.5-5 from base of 3.5 
	writeLines(sprintf("  cost.ramp:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$cost.ramp, 
					   (runPredNetCume(cost.ramp=def$cost.ramp*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0.5, 5, 0.05)
	g.cr <- sensitivityPlot("Cost.Ramp", def$cost.ramp, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(cost.ramp=x)}))

	# modify cost.scale from 0.5-5 from base of 2 
	writeLines(sprintf("  cost.scale:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$cost.scale, 
					   (runPredNetCume(cost.scale=def$cost.scale*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0.5, 5, 0.05)
	g.cs <- sensitivityPlot("Cost.Scale", def$cost.scale, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(cost.scale=x)}))

	# modify salary from 0-1 from base of 0.5
	writeLines(sprintf("  salary:\t1%% change from %.2f results in %.2f%% change in EVH",
					   def$salary, 
					   (runPredNetCume(salary=def$salary*1.01) / 
						runPredNetCume() - 1) * 100 ))
	z.in <- seq(0, 1, 0.05)
	g.sa <- sensitivityPlot("Salary", def$salary, z.in, 
							 sapply(z.in, function(x) {runPredNetCume(salary=x)}))

	# plot all of them
	writeLines("  making plot")
	fig.all <- arrangeGrob(g.gbr, g.shg, g.scg, 
						   g.shb, g.scb, g.mb, 
						   g.cr, g.cs, g.sa, ncol=3)

	return(fig.all)
}
	
sensitivityPlot <- function(label, def.value, input, output) {
	zd <- data.frame(input=input, output=output)
	zg <- suppressWarnings(ggplot(data=zd, aes(x=input, y=output)) + 
						   geom_vline(xintercept=def.value, col=def$col.be, linetype="dashed") +
						   geom_hline(yintercept=0, col=def$col.be, linetype="dotted") +
						   geom_line(col=def$col.benefit, size=1) +
						   theme_bw() +
						   labs(x=label, y="Exp Net Cume Benefit"))
	return(zg)
}

runHistograms <- function(sample=1000,
						  good.bad.ratio = def$good.bad.ratio, 
						  shape.good = def$shape.good, 
						  scale.good = def$scale.good, 
						  shape.bad = def$shape.bad, 
						  scale.bad = def$scale.bad,
						  do.annotate=FALSE,
						  list.plots=FALSE) {

	good.fit <- rweibull(sample * good.bad.ratio, shape=shape.good, scale=scale.good)
	bad.fit <- rweibull(sample * (1-good.bad.ratio), shape=shape.bad, scale=scale.bad)

	gglist <- list()
	gglist$fig1 <- ggplot(data=data.frame(tenure=c(good.fit, bad.fit)), aes(x=tenure)) + 
					geom_histogram(binwidth=1/12, fill=def$col.benefit) + 
					xlim(c(0,3)) +
					theme_bw() +
					theme(text = element_text(size=8)) +
					labs(title="All Employees", 
						 x="Tenure in Years", 
						 y="Count")

	gglist$fig2 <- ggplot(data=data.frame(tenure=good.fit), aes(x=tenure)) + 
					geom_histogram(binwidth=1/12, fill=def$col.good) + 
					xlim(c(0,3)) +
					theme_bw() +
					theme(text = element_text(size=8)) +
					labs(title="'Good Fit' Employees", 
						 x="Tenure in Years", 
						 y="Count")

	gglist$fig3 <- ggplot(data=data.frame(tenure=bad.fit), aes(x=tenure)) + 
				geom_histogram(binwidth=1/12, fill=def$col.bad) + 
				xlim(c(0,3)) +
				theme_bw() +
				theme(text = element_text(size=8)) +
				labs(title="'Bad Fit' Employees", 
					 x="Tenure in Years", 
					 y="Count")

	fig123 <- arrangeGrob(gglist$fig1, gglist$fig2, gglist$fig3, main="Employment Tenure", ncol=1)

	if (list.plots) {
		return(gglist)
	} else {
		return(fig123)
	}
}

runFigures <- function() {

	fig123 <- runHistograms(list.plot=TRUE, do.annotate=TRUE)

	lapply(names(fig123), 
		   function(x) {
			   fname <- sprintf("plots/pat002_%s.png",x) 
			   writeLines(sprintf("writing %s", fname))
			   ggsave(filename=sprintf("plots/pat002_%s.png",x), 
							  plot=fig123[[x]],
							  height=4, width=4,dpi=100)
		   })

	fig4567 <- runSim202(list.plot=TRUE, do.annotate=TRUE)

	lapply(names(fig4567), 
		   function(x) {
			   fname <- sprintf("plots/pat002_%s.png",x) 
			   writeLines(sprintf("writing %s", fname))
			   ggsave(filename=fname, plot=fig4567[[x]], height=4, width=4,dpi=100)
		   })

	return("Done.")
}
