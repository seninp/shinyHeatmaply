heatmaplyGadget<-function(obj,minHeight = 1000,...){
viewer=paneViewer(minHeight = 1000)
#UI----
  ui <- shinyUI(
    fluidPage(
      sidebarLayout(
        sidebarPanel(
          h4('Data'),
          uiOutput('data'),
          checkboxInput('showSample','Subset Data'),
          conditionalPanel('input.showSample',uiOutput('sample')),
          # br(),
          hr(),h4('Data Preprocessing'),
          column(width=4,selectizeInput('transpose','Transpose',choices = c('No'=FALSE,'Yes'=TRUE),selected = FALSE)),
          column(width=4,selectizeInput("transform_fun", "Transform", c(Identity=".",Sqrt='sqrt',log='log',Scale='scale',Normalize='normalize',Percentize='percentize',"Missing values"='is.na10', Correlation='cor'),selected = '.')),
          uiOutput('annoVars'),
          
          br(),hr(),h4('Row dendrogram'),
          column(width=6,selectizeInput("distFun_row", "Distance method", c(Euclidean="euclidean",Maximum='maximum',Manhattan='manhattan',Canberra='canberra',Binary='binary',Minkowski='minkowski'),selected = 'euclidean')),
          column(width=6,selectizeInput("hclustFun_row", "Clustering linkage", c(Complete= "complete",Single= "single",Average= "average",Mcquitty= "mcquitty",Median= "median",Centroid= "centroid",Ward.D= "ward.D",Ward.D2= "ward.D2"),selected = 'complete')),
          column(width=12,sliderInput("r", "Number of Clusters", min = 1, max = 15, value = 2)),    
          #column(width=4,numericInput("r", "Number of Clusters", min = 1, max = 20, value = 2, step = 1)),   
          
          br(),hr(),h4('Column dendrogram'),
          column(width=6,selectizeInput("distFun_col", "Distance method", c(Euclidean="euclidean",Maximum='maximum',Manhattan='manhattan',Canberra='canberra',Binary='binary',Minkowski='minkowski'),selected = 'euclidean')),
          column(width=6,selectizeInput("hclustFun_col", "Clustering linkage", c(Complete= "complete",Single= "single",Average= "average",Mcquitty= "mcquitty",Median= "median",Centroid= "centroid",Ward.D= "ward.D",Ward.D2= "ward.D2"),selected = 'complete')),
          column(width=12,sliderInput("c", "Number of Clusters", min = 1, max = 15, value = 2)),
          #column(width=4,numericInput("c", "Number of Clusters", min = 1, max = 20, value = 2, step = 1)),    
          
          br(),hr(),  h4('Additional Parameters'),
          
          column(3,checkboxInput('showColor','Color')),
          column(3,checkboxInput('showMargin','Layout')),
          column(3,checkboxInput('showDendo','Dendrogram')),
          hr(),
          conditionalPanel('input.showColor==1',
                           hr(),
                           h4('Color Manipulation'),
                           uiOutput('colUI'),
                           sliderInput("ncol", "Set Number of Colors", min = 1, max = 256, value = 256),
                           checkboxInput('colRngAuto','Auto Color Range',value = T),
                           conditionalPanel('!input.colRngAuto',uiOutput('colRng'))
          ),
          
          conditionalPanel('input.showDendo==1',
                           hr(),
                           h4('Dendrogram Manipulation'),
                           selectInput('dendrogram','Dendrogram Type',choices = c("both", "row", "column", "none"),selected = 'both'),
                           selectizeInput("seriation", "Seriation", c(OLO="OLO",GW="GW",Mean="mean",None="none"),selected = 'OLO'),
                           sliderInput('branches_lwd','Dendrogram Branch Width',value = 0.6,min=0,max=5,step = 0.1)
          ),             
          
          conditionalPanel('input.showMargin==1',
                           hr(),
                           h4('Widget Layout'),
                           column(4,textInput('main','Title','')),
                           column(4,textInput('xlab','X Title','')),
                           column(4,textInput('ylab','Y Title','')),
                           sliderInput('row_text_angle','Row Text Angle',value = 0,min=0,max=180),
                           sliderInput('column_text_angle','Column Text Angle',value = 45,min=0,max=180),
                           sliderInput("l", "Set Margin Width", min = 0, max = 200, value = 130),
                           sliderInput("b", "Set Margin Height", min = 0, max = 200, value = 40)
          )
        ),
        
        mainPanel(
          tabsetPanel(
            tabPanel("Heatmaply",
                     tags$a(id = 'downloadData', class = paste("btn btn-default shiny-download-link",'mybutton'), href = "", target = "_blank", download = NA, icon("clone"), 'Download Heatmap as HTML'),
                     tags$head(tags$style(".mybutton{color:white;background-color:blue;} .skin-black .sidebar .mybutton{color: green;}") ),
                     plotlyOutput("heatout",height='800px')
            ),
            tabPanel("Data",
                     dataTableOutput('tables')
            )
          ) 
        )
      )
    )
  )
#Server---- 

  server <- function(input, output,session) {	
    
    output$data=renderUI({
      d<-names(obj)
      selData=d[1]
      selectInput("data","Select Data",d,selected = selData)
    })
    
    data.sel=eventReactive(input$data,{
      as.data.frame(obj[[input$data]])
    })  
    
    observeEvent(data.sel(),{
      output$annoVars<-renderUI({
        data.in=data.sel()
        NM=NULL
        
        if(any(sapply(data.in,class)=='factor')){
          NM=names(data.in)[which(sapply(data.in,class)=='factor')]  
        } 
        column(width=4,
               selectizeInput('annoVar','Annotation',choices = names(data.in),selected=NM,multiple=T)
        )
      })
      
      #Sampling UI ----  
      output$sample<-renderUI({
        list(
          column(4,textInput(inputId = 'setSeed',label = 'Seed',value = sample(1:10000,1))),
          column(4,numericInput(inputId = 'selRows',label = 'Number of Rows',min=1,max=pmin(500,nrow(data.sel())),value = pmin(500,nrow(data.sel())))),
          column(4,selectizeInput('selCols','Columns Subset',choices = names(data.sel()),multiple=T))
        )
      })
    })
    
    output$colUI<-renderUI({
      colSel=ifelse(input$transform_fun=='cor','RdBu','Vidiris')
      selectizeInput(inputId ="pal", label ="Select Color Palette",
                     choices = c('Vidiris (Sequential)'="viridis",
                                 'Magma (Sequential)'="magma",
                                 'Plasma (Sequential)'="plasma",
                                 'Inferno (Sequential)'="inferno",
                                 'Magma (Sequential)'="magma",
                                 'Magma (Sequential)'="magma",
                                 
                                 'RdBu (Diverging)'="RdBu",
                                 'RdYlBu (Diverging)'="RdYlBu",
                                 'RdYlGn (Diverging)'="RdYlGn",
                                 'BrBG (Diverging)'="BrBG",
                                 'Spectral (Diverging)'="Spectral",
                                 
                                 'BuGn (Sequential)'='BuGn',
                                 'PuBuGn (Sequential)'='PuBuGn',
                                 'YlOrRd (Sequential)'='YlOrRd',
                                 'Heat (Sequential)'='heat.colors',
                                 'Grey (Sequential)'='grey.colors'),
                     selected=colSel)
    })
    
    output$colRng=renderUI({
      if(!is.null(data.sel())) {
        rng=range(data.sel(),na.rm = TRUE)
      }else{
        rng=range(mtcars) # TODO: this should probably be changed
      }
      # sliderInput("colorRng", "Set Color Range", min = round(rng[1],1), max = round(rng[2],1), step = .1, value = rng)  
      n_data = nrow(data.sel())
      
      min_min_range = ifelse(input$transform_fun=='cor',-1,-Inf)
      min_max_range = ifelse(input$transform_fun=='cor',1,rng[1])
      min_value = ifelse(input$transform_fun=='cor',-1,rng[1])
      
      max_min_range = ifelse(input$transform_fun=='cor',-1,rng[2])
      max_max_range = ifelse(input$transform_fun=='cor',1,Inf)
      max_value = ifelse(input$transform_fun=='cor',1,rng[2])
      
      a_good_step = 0.1 # (max_range-min_range) / n_data
      
      list(
        numericInput("colorRng_min", "Set Color Range (min)", value = min_value, min = min_min_range, max = min_max_range, step = a_good_step),
        numericInput("colorRng_max", "Set Color Range (max)", value = max_value, min = max_min_range, max = max_max_range, step = a_good_step)
      )
      
    })
    
    interactiveHeatmap<- reactive({
      data.in=data.sel()
      if(input$showSample){
        if(!is.null(input$selRows)){
          set.seed(input$setSeed)
          if((input$selRows >= 2) & (input$selRows < nrow(data.in))){
            # if input$selRows == nrow(data.in) then we should not do anything (this save refreshing when clicking the subset button)
            if(length(input$selCols)<=1) data.in=data.in[sample(1:nrow(data.in),pmin(500,input$selRows)),]
            if(length(input$selCols)>1) data.in=data.in[sample(1:nrow(data.in),pmin(500,input$selRows)),input$selCols]
          }
        }
      }
      
      if(length(input$annoVar)>0){
        if(all(input$annoVar%in%names(data.in))) data.in=data.in%>%mutate_each_(funs(factor),input$annoVar)
      } 
      
      ss_num =  sapply(data.in, is.numeric) # in order to only transform the numeric values
      
      if(input$transpose) data.in=t(data.in)
      if(input$transform_fun!='.'){
        if(input$transform_fun=='is.na10') data.in=is.na10(data.in)
        if(input$transform_fun=='cor'){
          updateCheckboxInput(session = session,inputId = 'showColor',value = T)
          updateCheckboxInput(session = session,inputId = 'colRngAuto',value = F)
          data.in=cor(data.in[, ss_num],use = "pairwise.complete.obs")
        }
        if(input$transform_fun=='log') data.in[, ss_num]= apply(data.in[, ss_num],2,log)
        if(input$transform_fun=='sqrt') data.in[, ss_num]= apply(data.in[, ss_num],2,sqrt) 
        if(input$transform_fun=='normalize') data.in=normalize(data.in)
        if(input$transform_fun=='scale') data.in[, ss_num] = scale(data.in[, ss_num])
        if(input$transform_fun=='percentize') data.in=percentize(data.in)
      } 
      
      
      if(!is.null(input$tables_true_search_columns)) 
        data.in=data.in[activeRows(input$tables_true_search_columns,data.in),]
      if(input$colRngAuto){
        ColLimits=NULL 
      }else{
        ColLimits=c(input$colorRng_min, input$colorRng_max)
      }
      
      distfun_row = function(x) dist(x, method = input$distFun_row)
      distfun_col =  function(x) dist(x, method = input$distFun_col)
      
      hclustfun_row = function(x) hclust(x, method = input$hclustFun_row)
      hclustfun_col = function(x) hclust(x, method = input$hclustFun_col)
      
      heatmaply(data.in,
                main = input$main,xlab = input$xlab,ylab = input$ylab,
                row_text_angle = input$row_text_angle,
                column_text_angle = input$column_text_angle,
                dendrogram = input$dendrogram,
                branches_lwd = input$branches_lwd,
                seriate = input$seriation,
                colors=eval(parse(text=paste0(input$pal,'(',input$ncol,')'))),
                distfun_row =  distfun_row,
                hclustfun_row = hclustfun_row,
                distfun_col = distfun_col,
                hclustfun_col = hclustfun_col,
                k_col = input$c, 
                k_row = input$r,
                limits = ColLimits) %>% 
        layout(margin = list(l = input$l, b = input$b))
      
    })
    
    observeEvent(data.sel(),{
      output$heatout <- renderPlotly({
          interactiveHeatmap()
      })
    })
    
    output$tables=renderDataTable(data.sel(),server = T,filter='top',
                                  extensions = c('Scroller','FixedHeader','FixedColumns','Buttons','ColReorder'),
                                  options = list(
                                    dom = 't',
                                    buttons = c('copy', 'csv', 'excel', 'pdf', 'print','colvis'),
                                    colReorder = TRUE,
                                    scrollX = TRUE,
                                    fixedColumns = TRUE,
                                    fixedHeader = TRUE,
                                    deferRender = TRUE,
                                    scrollY = 500,
                                    scroller = TRUE
                                  ))
    
    #Clone Heatmap ----
    observeEvent({interactiveHeatmap()},{
      h<-interactiveHeatmap()
      
      l<-list(main = input$main,xlab = input$xlab,ylab = input$ylab,
              row_text_angle = input$row_text_angle,
              column_text_angle = input$column_text_angle,
              dendrogram = input$dendrogram,
              branches_lwd = input$branches_lwd,
              seriate = input$seriation,
              colors=paste0(input$pal,'(',input$ncol,')'),
              distfun_row =  input$distFun_row,
              hclustfun_row = input$hclustFun_row,
              distfun_col = input$distFun_col,
              hclustfun_col = input$hclustFun_col,
              k_col = input$c, 
              k_row = input$r,
              limits = paste(c(input$colorRng_min, input$colorRng_max),collapse=',')
      )
      
      #l=l[!l=='']
      l=data.frame(Parameter=names(l),Value=do.call('rbind',l),row.names = NULL,stringsAsFactors = F)
      l[which(l$Value==''),2]='NULL'
      paramTbl=print(xtable::xtable(l),type = 'html',include.rownames=FALSE,print.results = F,html.table.attributes = c('border=0'))
      
      
      h$width='100%'
      h$height='800px'
      s<-tags$div(style="position: relative; bottom: 5px;",
                  html2tagList(paramTbl),
                  tags$em('This heatmap visualization was created using',
                          tags$a(href="https://github.com/yonicd/shinyHeatmaply/",
                                 target="_blank",'shinyHeatmaply')
                  )
      )
      
      output$downloadData <- downloadHandler(
        filename = function() {
          paste("heatmaply-", gsub(' ','_',Sys.time()), ".html", sep="")
        },
        content = function(file) {
          libdir <- paste(tools::file_path_sans_ext(basename(file)),"_files", sep = "")
          
          htmltools::save_html(htmltools::browsable(htmltools::tagList(h,s)),file=file,libdir = libdir)
          if (!htmlwidgets:::pandoc_available()) {
            stop("Saving a widget with selfcontained = TRUE requires pandoc. For details see:\n", 
                 "https://github.com/rstudio/rmarkdown/blob/master/PANDOC.md")
          }
          
          fileTemp<-readLines(file)
          tblTempIdx=grep('table',fileTemp)
          tblTempVal=fileTemp[tblTempIdx[1]:tblTempIdx[2]]
          tblTempVal=gsub('^\\s+','',tblTempVal)
          fileTemp[tblTempIdx[1]:tblTempIdx[2]]=tblTempVal
          fileTemp=fileTemp[!nchar(fileTemp)==0]
          cat(HTML(fileTemp),file=file)
          
          htmlwidgets:::pandoc_self_contained_html(file, file)
          
          unlink(libdir, recursive = TRUE)
        }
      )
    })
    
  }
  
  runGadget(ui, server, viewer = viewer)

}