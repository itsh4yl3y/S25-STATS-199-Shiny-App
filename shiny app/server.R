# server.R =====================================================================

server <- function(input, output, session) {
  
  # ======================================================================
  # TAB 1: One Proportion Test
  # ======================================================================
  
  calc_results <- reactive({
    p0 <- input$p
    n <- input$n
    ph <- input$p_hat
    x <- round(ph * n)
    if (n <= 0 || x < 0 || x > n) {
      return(NULL)
    }
    prop.test(x, n, p = p0, alternative = input$alternative, 
              conf.level = as.numeric(input$conf_level))
  })
  
  # ----------------------------------------------------------------------
  # Confidence interval check box
  # ----------------------------------------------------------------------
  observe({
    if (input$show_ci) {
      test_results <- calc_results()
      if (is.null(test_results)) {
        output$ci_table <- renderText({ "" })
        output$ci_conclusion <- renderText({ "Invalid input parameters." })
        return()
      }
      ci <- test_results$conf.int
      output$ci_label <- renderText({"Confidence Interval"})
      output$ci_conclusion <- renderText({
        paste0("We are ", round(as.numeric(input$conf_level) * 100),
               "% confident that the true population proportion lies in the interval [",
               round(ci[1], 3), ", ", round(ci[2], 3), "].")
      })
    } else {
      # hide or clear these outputs if the checkbox is not selected
      output$ci_label <- renderText({ "" })
      output$ci_conclusion <- renderText({ "" })
    }
  })
  
  # ----------------------------------------------------------------------
  # Plot
  # ----------------------------------------------------------------------
  output$plot <- renderPlot({
    # if neither test or CI is selected, show blank plot
    if (!input$show_test && !input$show_ci) {
      plot.new()
      text(0.5, 0.5, "No test or CI selected.", cex = 1.4)
      return()
    }
    test_res <- calc_results()
    if (is.null(test_res)) {
      plot.new()
      text(0.5, 0.5, "Invalid input parameters", cex = 1.5)
      return()
    }
    
    x_vals <- 0:input$n
    x_obs <- round(input$p_hat * input$n)
    binom_probs<- dbinom(x_vals, size = input$n, prob = input$p)
    
    # default bar color
    bar_colors <- rep("lightgrey", length(x_vals))
    
    # highlight region depending on alternative
    if (input$alternative == "less") {
      bar_colors[x_vals <= x_obs] <- "#FFD100"
    } else if (input$alternative == "greater") {
      bar_colors[x_vals >= x_obs] <- "#FFD100"
    } else {
      # two-sided
      mu <- input$n * input$p
      dist_from_mean <- abs(x_obs - mu)
      x_lower <- floor(mu - dist_from_mean)
      x_upper <- ceiling(mu + dist_from_mean)
      index <- which(x_vals <= x_lower | x_vals >= x_upper)
      bar_colors[index] <- "#FFD100"
    }
    barplot(
      height = binom_probs, 
      names.arg = x_vals, 
      col = bar_colors,
      xlab = "Number of Successes (x)",
      ylab = "Probability",
      main = "Sampling Distribution Under Null Hypothesis"
    )
  })
  
  # ----------------------------------------------------------------------
  # Show or hide the test results and conclusions
  # ----------------------------------------------------------------------
  observe({
    if (input$show_test) {
      # results table
      output$results_table <- render_gt({
        test_res <- calc_results()
        if (is.null(test_res)) {
          return(gt(data.frame(Warning = "Invalid input parameters.")))
        }
        p_value <- test_res$p.value
        alt_str <- switch(
          input$alternative,
          "less"      = paste0("p < ", input$p),
          "greater"   = paste0("p > ", input$p),
          "two.sided" = paste0("p ≠ ", input$p)
        )

        df <- data.frame(
          label = c(
            "Null Hypothesis",
            "Alternative Hypothesis",
            "Sample Size",
            "Number of Successes",
            "Sample Proportion",
            "p-value"
          ),
          value = c(
            paste0("p = ", input$p),
            alt_str,
            input$n,
            round(input$p_hat * input$n),
            round(test_res$estimate, 3),
            format(p_value, digits = 4)
          )
        )
        
        df |> 
          gt() |> tab_header(title = "One Proportion Test") |> 
          tab_options(column_labels.hidden = TRUE) 
      })
      
      # conclusions (separate table below)
      output$conclusions <- render_gt({
        test_res <- calc_results()
        if (is.null(test_res)) {
          return(gt(data.frame(Warning = "Invalid input parameters.")))
        }
        p_value   <- test_res$p.value
        alpha     <- c(0.01, 0.05, 0.1)
        decisions <- ifelse(p_value < alpha, "rejected", "not rejected")
        
        df <- data.frame(
          conclusions = paste0("The null hypothesis is ", decisions, " at \u03B1 = ", alpha)
        )
        
        df |> 
          gt() |> 
          tab_header(title = "Test Conclusions") |> 
          tab_options(column_labels.hidden = TRUE)
      })
    } else {
      # clear if show_test is off
      output$results_table <- renderText({ "" })
      output$conclusions   <- renderText({ "" })
    }
  })
 
  # ======================================================================
  # TAB 2: One Mean
  # ======================================================================
  
  one_mean_test_results <- reactive({
    
    # get inputs from ui.R
    mu <- input$mu
    n <- input$n
    x_bar <- input$x_bar
    s <- input$s
    df <- n - 1
    
    # validate inputs
    if (n <= 0 || s <= 0) {
      return(NULL)
    }
    
    # t-statistic
    t_stat <- (x_bar - mu) / (s / sqrt(n))
    p_val <- switch(
      input$mean_alt,
      "less" = pt(t_stat, df = df),
      "greater" = 1 - pt(t_stat, df = df),
      "two.sided" = 2 * pt(-abs(t_stat), df = df)
    )
    
    # construct a fake "t.test" object
    list(
      statistic = c(t = t_stat),
      p.value = p_val,
      estimate = c(mean = x_bar),
      null.value = c(mu = mu),
      alternative = input$mean_alt,
      method = "One Sample t-test",
      data.name = "Manually computed",
      parameter = c(df = df)
    )
  })
  
  output$one_mean_test_table <- render_gt({
    
    # get test results
    test_res <- one_mean_test_results()  
    
    alternative_str <- switch(
      input$mean_alt, 
      "less" = paste0("μ < ", input$mu),   # left-sided
      "greater" = paste0("μ > ", input$mu), # right-sided
      "two.sided" = paste0("μ ≠ ", input$mu) # two-sided
    )
    
    df_results <- data.frame(
      Label = c("Null Hypothesis",
                "Alternative Hypothesis",
                "Sample Size",
                "Sample Mean",
                "Sample SD",
                "Degrees of Freedom",
                "p-value"),
      
      Value = c(paste0("μ = ", input$mu), 
                alternative_str, 
                input$n, 
                round(input$x_bar, 3),
                round(input$s, 3),
                round(test_res$parameter["df"], 2),
                format(test_res$p.value, digits = 4))
    )
    
    gt(df_results) |>
      tab_header(title = "One Sample t-test Results") 
  })
  
  output$one_mean_plot <- renderPlot({
    
    # get test results
    test_res <- one_mean_test_results()
    
    if (is.null(test_res)) {
      plot.new()
      text(0.5, 0.5, "Invalid input parameters", cex = 1.5)
      return()
    }
    
    n <- input$n
    df <- n - 1
    mu <- input$mu
    x_bar <- input$x_bar
    s <- input$s
    se <- s / sqrt(n)
    t_stat <- (x_bar - mu) / se
    
    x_vals <- seq(-4, 4, length.out = 400)
    y_vals <- dt(x_vals, df)
    
    # fun fact: #2774AE is the official UCLA Blue color 
    #bar_color <- "#2774AE"
    shade_color <- "#FFD100"
    
    plot(x_vals, y_vals, type = "l", lwd = 2, col = "lightgrey",
         xlab = "t-value", ylab = "Density",
         main = "t-Distribution Under Null Hypothesis")
    
    # shade gold area based on alternative
    if (input$mean_alt == "less") {
      x_shade <- x_vals[x_vals <= t_stat]
      y_shade <- y_vals[x_vals <= t_stat]
      polygon(c(min(x_shade), x_shade, max(x_shade)),
              c(0, y_shade, 0),
              col = shade_color, border = NA)
      
    } else if (input$mean_alt == "greater") {
      x_shade <- x_vals[x_vals >= t_stat]
      y_shade <- y_vals[x_vals >= t_stat]
      polygon(c(min(x_shade), x_shade, max(x_shade)),
              c(0, y_shade, 0),
              col = shade_color, border = NA)
      
    } else if (input$mean_alt == "two.sided") {
      t_crit <- abs(t_stat)
      
      # left tail
      x_left <- x_vals[x_vals <= -t_crit]
      y_left <- y_vals[x_vals <= -t_crit]
      polygon(c(min(x_left), x_left, max(x_left)),
              c(0, y_left, 0),
              col = shade_color, border = NA)
      
      # right tail
      x_right <- x_vals[x_vals >= t_crit]
      y_right <- y_vals[x_vals >= t_crit]
      polygon(c(min(x_right), x_right, max(x_right)),
              c(0, y_right, 0),
              col = shade_color, border = NA)
    }
  })
  
  # ======================================================================
  # TAB 3: Difference Two Proportion
  # ======================================================================
  
  
  
  
  # ======================================================================
  # TAB 4: Difference Two Means
  # ======================================================================
  
  
  
  
  # ======================================================================
  # TAB 5: Normal Distribution
  # ======================================================================
  
  norm_result <- reactive({
    # Validate standard deviation
    if (input$sd <= 0) {
      return(list(error = "Standard deviation must be positive."))
    }
    
    mean <- input$mean
    sd <- input$sd
    range_type <- input$range
    num1 <- input$num1
    num2 <- input$num2
    
    # Full normal curve
    x_vals <- seq(mean - 4 * sd, mean + 4 * sd, length.out = 1000)
    y_vals <- dnorm(x_vals, mean, sd)
    df <- data.frame(x = x_vals, y = y_vals)
    
    # Initialize
    prob <- NA
    error_msg <- NULL
    shade_df <- data.frame(x = numeric(0), y = numeric(0))
    
    # Handle range cases
    if (range_type == "above") {
      prob <- pnorm(num1, mean, sd, lower.tail = FALSE)
      shade_df <- df[df$x >= num1, ]
      
    } else if (range_type == "below") {
      prob <- pnorm(num1, mean, sd)
      shade_df <- df[df$x <= num1, ]
      
    } else if (range_type == "between") {
      if (is.null(num2) || num2 < num1) {
        error_msg <- "Please ensure Value 2 is greater than Value 1 for 'Between'."
      } else {
        prob <- pnorm(num2, mean, sd) - pnorm(num1, mean, sd)
        shade_df <- df[df$x >= num1 & df$x <= num2, ]
      }
      
    } else if (range_type == "outside") {
      if (is.null(num2) || num2 < num1) {
        error_msg <- "Please ensure Value 2 is greater than Value 1 for 'Outside'."
      } else {
        prob <- 1 - (pnorm(num2, mean, sd) - pnorm(num1, mean, sd))
        shade_df <- rbind(
          df[df$x <= num1, ],
          df[df$x >= num2, ]
        )
      }
    }
    
    if (!is.null(error_msg)) {
      return(list(error = error_msg))
    }
    
    list(prob = prob, data = df, shaded = shade_df)
  })
  
  output$norm_prob <- renderText({
    res <- norm_result()
    if (!is.null(res$error)) return(res$error)
    paste0("Probability = ", round(res$prob, 4))
  })
  
  output$norm_plot <- renderPlot({
    res <- norm_result()
    if (!is.null(res$error)) return(NULL)
    
    base_plot <- ggplot(res$data, aes(x, y)) +
      geom_line(color = "blue") +
      labs(
        title = "Normal Distribution",
        x = "X", y = "Density"
      ) +
      theme_minimal()
    
    if (input$range == "outside") {
      # For 'outside', plot two separate shaded areas
      shade_left  <- subset(res$data, x <= input$num1)
      shade_right <- subset(res$data, x >= input$num2)
      
      base_plot +
        geom_area(data = shade_left, aes(x, y), fill = "lightblue", alpha = 0.5) +
        geom_area(data = shade_right, aes(x, y), fill = "lightblue", alpha = 0.5)
      
    } else {
      # For all other cases
      base_plot +
        geom_area(data = res$shaded, aes(x, y), fill = "lightblue", alpha = 0.5)
    }
  })
  
  output$dynamic_inputs <- renderUI({
    if (input$range %in% c("between", "outside")) {
      tagList(
        numericInput("num1", "Value 1", value = -1.96),
        numericInput("num2", "Value 2", value = 1.96)
      )
    } else {
      numericInput("num1", "Value 1", value = 1.96)
    }
  })



  # ======================================================================
  # TAB 6: t-Distribution
  # ======================================================================



  # ======================================================================
  # TAB 7: Chi-square
  # ======================================================================

}
















