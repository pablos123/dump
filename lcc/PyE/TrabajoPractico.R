#Libraries and back-end stuff --------------------------------------------------------------------------------
#install.packages("janitor") #to install packages
#Ggplot library
library(ggplot2)
dev.off() #If ggplot2 is not working you can use this

#Others
library(dplyr)
library(tidyr)
library(tidyverse)
library(hrbrthemes)
library(viridis)
library(RColorBrewer)
library(forcats)
library(ggExtra)
library(hrbrthemes)
library(scales)
library(data.table)
library(formattable)
library(janitor)

#To solve the fonts warnings
library(extrafont)
font_import()
loadfonts(device = "win")


#Leemos la base de datos
database <- read.table("~/TP1/base2.txt", header = TRUE, sep = "\t")
attach(database)

#El resumen de la base de datos
summary(database)

#Sets the max print cap
options("max.print" = 100000)

#Tablas ---------------------------------------------------------------
#Especies
newData <- as.data.frame(table(especie))
names(newData)[1] = "Especie"
names(newData)[2] = "Cantidad"
newData <- newData %>%
  adorn_totals("row")
formattable(newData)

#Origen/Especie
Total <- c(218, 132)
data <- as.data.frame(rbind(table(especie, origen), Total))
formattable(data)

#Tabla de frecuencia para la altura
segundaB <- table(cut(altura, seq(0, 36, by = 2), right = FALSE))
segundaB <- as.data.frame(segundaB)
terceraB <- segundaB[2]/length(altura)
cuartaB <- cumsum(segundaB[2])
quintaB <- cumsum(terceraB)
segundoGrafico <- cbind(segundaB, terceraB, cuartaB, quintaB)

names(segundoGrafico)[1]="Altura en m"
names(segundoGrafico)[2]="Frec abs"
names(segundoGrafico)[3]="Frec rel"
names(segundoGrafico)[4]="Frec abs acum"
names(segundoGrafico)[5]="Frec rel acum"
segundoGrafico <- segundoGrafico %>%
  adorn_totals("row")
segundoGrafico[nrow(segundoGrafico), 4] = "-"
segundoGrafico[nrow(segundoGrafico), 5] = "-"
formattable(as.data.frame(segundoGrafico))

#Tabla de frecuencia para el diametro
segundaB <- table(cut(diametro, seq(0, 160, by = 10), right = FALSE))
segundaB <- as.data.frame(segundaB)
terceraB <- segundaB[2]/length(diametro)
cuartaB <- cumsum(segundaB[2])
quintaB <- cumsum(terceraB)
segundoGrafico <- cbind(segundaB, terceraB, cuartaB, quintaB)

names(segundoGrafico)[1]="Diametro en cm"
names(segundoGrafico)[2]="Frec abs"
names(segundoGrafico)[3]="Frec rel"
names(segundoGrafico)[4]="Frec abs acum"
names(segundoGrafico)[5]="Frec rel acum"
formattable(as.data.frame(segundoGrafico))
segundoGrafico <- segundoGrafico %>%
  adorn_totals("row")
segundoGrafico[nrow(segundoGrafico), 4] = "-"
segundoGrafico[nrow(segundoGrafico), 5] = "-"
formattable(as.data.frame(segundoGrafico))

#Tabla de frecuencia para inclinacion
segundaB <- table(cut(inclinacion, seq(0, 51, by = 3), right = FALSE))
segundaB <- as.data.frame(segundaB)
terceraB <- segundaB[2]/length(inclinacion)
cuartaB <- cumsum(segundaB[2])
quintaB <- cumsum(terceraB)
segundoGrafico <- cbind(segundaB, terceraB, cuartaB, quintaB)

names(segundoGrafico)[1]="Inclinacion en grados"
names(segundoGrafico)[2]="Frec abs"
names(segundoGrafico)[3]="Frec rel"
names(segundoGrafico)[4]="Frec abs acum"
names(segundoGrafico)[5]="Frec rel acum"
formattable(as.data.frame(segundoGrafico))
segundoGrafico <- segundoGrafico %>%
  adorn_totals("row")
segundoGrafico[nrow(segundoGrafico), 4] = "-"
segundoGrafico[nrow(segundoGrafico), 5] = "-"
formattable(as.data.frame(segundoGrafico))

#Tabla de frecuencia para brotes
segundaA <- table(brotes)
segundaA <- as.data.frame(segundaA)
terceraA<-segundaA[2]/length(brotes)
cuartaA <- cumsum(segundaA[2])
quintaA <- cumsum(terceraA)

primerGrafico <- cbind(segundaA, terceraA, cuartaA, quintaA)
names(primerGrafico)[1]="Brotes"
names(primerGrafico)[2]="Frec abs"
names(primerGrafico)[3]="Frec rel"
names(primerGrafico)[4]="Frec abs acum"
names(primerGrafico)[5]="Frec rel acum"
primerGrafico <- primerGrafico %>%
  adorn_totals("row")
primerGrafico[nrow(primerGrafico), 4] = "-"
primerGrafico[nrow(primerGrafico), 5] = "-"
formattable(as.data.frame(primerGrafico))


mean(brotes)
median(brotes)
range(brotes)
var(brotes)
sd(brotes)
quantile(brotes)
IQR(brotes)

mean(inclinacion)
median(inclinacion)
range(inclinacion)
var(inclinacion)
sd(inclinacion)
quantile(inclinacion)
IQR(inclinacion)

mean(altura)
median(altura)
range(altura)
var(altura)
sd(altura)
quantile(altura)
IQR(altura)

mean(diametro)
median(diametro)
range(diametro)
var(diametro)
sd(diametro)
quantile(diametro)
IQR(diametro)


#Origenes  --------------------------------------------------------------------------------
#Grafico de torta para los origenes
u <- table(origen)[1] / 350 * 100
v <- table(origen)[2] / 350  * 100
pie(table(origen), labels = c(paste("Exotico\n", trunc_number_n_decimals(u, 3), "%"),paste("Nativo\n", trunc_number_n_decimals(v, 3),"%")), clockwise = TRUE, init.angle = 90, main = "ORIGEN DE LAS ESPECIES, CENSO FORESTAL URBANO PÚBLICO, BUENOS AIRES 2011", cex= 1.01, cex.main = 0.85, col = c("#732c4e", "#677d4e"))
mtext("Fuente: Censo Forestal Urbano Publico",side=1,line=2, at=1.1,cex=0.8, font = 3, col = "black")

#Origen de arboles por especie
database %>%
  ggplot(aes(x=especie, fill = origen)) + 
  theme_ipsum() +
  theme(
    plot.title = element_text(hjust = 0.5,size = 11)
  ) +
  geom_bar(position ="dodge") +
  ggtitle("ORIGEN DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Especie") + 
  ylab("Cantidad") +
  scale_fill_manual("Origen", values = c("Exotico" = "#732c4e", "Nativo/Autoctono" = "#677d4e")) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  coord_flip()

#Especies  --------------------------------------------------------------------------------
#Grafico de barras para las especies
database %>%
  ggplot(aes(x=especie)) +
  geom_bar(color="gold", fill="#6b5d93", alpha=1, size = 1) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11)
  ) +
  ggtitle("ESPECIES DE ARBOLES, BUENOS AIRES 2011") +
  xlab("Especie") + 
  ylab("Cantidad") + 
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  coord_flip()

#Brotes -------------------------------------------------------------------------------- 
#Grafico de bastones para la cantidad de arboles por cantidad de brotes
newData <- data.frame(x = c(0,1,2,3,4,5,6,7,8,9), y = c(2,18,52,91,85,61,27,11,2,1))

newData %>%
ggplot(aes(x = x, y = y)) +
  geom_point(size = 2) +
  theme_test() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11)
  ) +
  geom_segment(aes(x=x, xend=x, y=0, yend=y), size = 1.1) +
  ggtitle("BROTES DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Cantidad de brotes") + ylab("Cantidad de arboles")+ 
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, by = 10)) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(limits = c(0, 9), breaks = seq(0, 9, by = 1)) + geom_hline(aes(yintercept = y), linetype = "dotted", col = "#865d93")
  
#Boxplot brotes en funcion de la especie
database %>%
  ggplot( aes(x=especie, y=brotes)) +
  geom_boxplot(color="#000000", fill="#732c4e", alpha=0.4) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank()
  ) +
  ggtitle("BROTES DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Cantidad de brotes") + coord_flip() +
  scale_y_continuous(breaks = seq(0, 9, by = 1), labels = seq(0, 9, 1))



#Altura --------------------------------------------------------------------------------
#Altura promedio segun la especie
ggplot(database %>% group_by(especie) %>% 
  summarise(alturaPromedio = mean(altura)), aes(x = especie, y = alturaPromedio)) +
  theme_ipsum() +
  geom_count(stat="identity", col = "#6c0000", size = 8) +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Altura promedio en m")

#Boxplot altura en funcion de la especie
database %>%
  ggplot( aes(x=especie, y=altura)) +
  geom_boxplot(color="#000000", fill="#732c4e", alpha=0.4) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11)
  ) +
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Altura en m") + coord_flip()

#Histograma para ver la cantidad de arboles segun su altura
database %>%
  ggplot(aes(x=altura)) +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  geom_histogram(binwidth = 2, fill="#69b3a2", color="#e9ecef", alpha=0.9)+
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Altura en m") + ylab("Cantidad de arboles") +
  scale_y_continuous(limits = c(0, 60), breaks = seq(0, 60, by = 15)) +
  scale_x_continuous(limits = c(-1, 35), breaks = seq(-1, 35, by = 2), labels = seq(0, 36, by = 2)) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  geom_freqpoly(binwidth = 2, linetype = "longdash", col = "#09002c")
table(altura) #test

#Poligono de frecuencia relativa para acompañar el histograma
tablaAltura <- cbind(table(cut(altura, seq(0, 36, by = 2), right = FALSE)))
relTablaAltura <- tablaAltura[,1]/length(altura)
newDataFrame <- as.data.frame(relTablaAltura)
newDataFrame

newDataFrame %>%
  ggplot( aes(x = seq(0, 34, by = 2), y = relTablaAltura))  +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  geom_freqpoly(stat = "identity") +
  xlab("Altura en m") + ylab("Frecuencia relativa") + 
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(-1, 35, by = 2), limits = c(-1, 35), labels = seq(0, 36, by = 2))

#Poligono de frecuencia relativa acumulada para acompañar el histograma
database %>%
  ggplot(aes(x=altura)) + 
  geom_line(stat = "ecdf") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Altura en metros") + ylab("Frecuencia relativa acumulada") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(0, 36, by = 2))

#Inclinacion --------------------------------------------------------------------------------
#Scatterplot inclinacion en funcion de la altura
scatterGraph <- database %>%
ggplot(aes(x = altura, y = inclinacion)) +
  theme_ft_rc() +
  theme(
    axis.title.x = element_text(hjust=0.5,size=9),
    axis.title.y = element_text(hjust=0.5,size=9)
    ) +
  geom_point(
    color="#4095a2",
    fill="#5595a2",
    shape=16,
    alpha=0.3,
    size=1,
    stroke = 2
  ) + 
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  ylab("Inclinacion en grados") + xlab("Altura en m")

ggMarginal(scatterGraph, type="histogram")

#Scatterplot inclinacion en funcion del diametro
scatterGraph <- database %>%
  ggplot(aes(x = diametro, y = inclinacion)) +
  theme_ft_rc() +
  theme(
    axis.title.x = element_text(hjust=0.5,size=9),
    axis.title.y = element_text(hjust=0.5,size=9)
  ) +
  geom_point(
    color="#4095a2",
    fill="#5595a2",
    shape=16,
    alpha=0.3,
    size=1,
    stroke = 2
  ) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  ylab("Inclinacion en grados") + xlab("Diametro en cm")

ggMarginal(scatterGraph, type="histogram")

# Boxplot inclinacion en funcion de la especie
database %>%
  ggplot( aes(x=especie, y=inclinacion)) +
  geom_boxplot(color="#000000", fill="#732c4e", alpha=0.4) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11)
  ) +
  ggtitle("INCLINACION DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Inclinacion en grados") + coord_flip()

#Histograma para ver la cantidad de arboles segun su inclinacion
database %>%
  ggplot(aes(x = inclinacion)) +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  geom_histogram(binwidth = 3, boundary = 0, fill="#69b3a2", color="#e9ecef", alpha=0.9)+
  ggtitle("INCLINACION DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Inclinacion en grados") + ylab("Cantidad de arboles") +
  scale_y_continuous(limits = c(0, 260), breaks = seq(0, 260, by = 20)) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(0, 51, by = 3))

cbind(table(inclinacion)) #test

#Grafico para acompañar el histograma
database %>%
  ggplot(aes(x = inclinacion)) +
  theme_light() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  geom_freqpoly(stat = "count") +
  xlab("Inclinacion en grados") + ylab("Cantidad de arboles") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  ggtitle("INCLINACION DE LOS ARBOLES, BUENOS AIRES 2011") +
  scale_x_continuous(breaks = seq(0, 51, by = 3))

#Poligono de frecuencia relativa para acompañar el histograma
tablaInclinacion <- cbind(table(cut(inclinacion, seq(0, 51, by = 3), right = FALSE)))
relTablaInclinacion <- tablaInclinacion[,1]/length(inclinacion)
newDataFrame <- as.data.frame(relTablaInclinacion)
newDataFrame

newDataFrame %>%
  ggplot( aes(x = seq(0, 48, by = 3), y = relTablaInclinacion))  +
  theme_ipsum() +
  theme(
    legend.position = "none",
    plot.title = element_text(hjust = 0.5, size = 11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("ALTURA DE LOS ARBOLES, BUENOS AIRES 2011") +
  geom_freqpoly(stat = "identity") +
  xlab("Inclinacion en grados") + ylab("Frecuencia relativa") + 
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(-1, 52, by = 3), limits = c(-1, 52), labels = seq(0, 51, by = 3))

#Poligono de frecuencia relativa acumulada para acompañar el histograma
database %>%
  ggplot(aes(x=inclinacion)) + 
  geom_line(stat = "ecdf") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("INCLINACION DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Inclinacion en grados") + ylab("Frecuencia relativa acumulada") +
  scale_y_continuous(limits = c(0.7, 1.0)) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(0, 51, by = 3))

#Function for trunc the decimals
trunc_number_n_decimals <- function(numberToTrunc, nDecimals){
  numberToTrunc <- numberToTrunc + (10^-(nDecimals+5))
  splitNumber <- strsplit(x=format(numberToTrunc, digits=20, format=f), split="\\.")[[1]]
  decimalPartTrunc <- substr(x=splitNumber[2], start=1, stop=nDecimals)
  truncatedNumber <- as.numeric(paste0(splitNumber[1], ".", decimalPartTrunc))
  return(truncatedNumber)
}


#To see the warnings if there is somehow one ;)
warnings()

#Diametro -------------------------------------------------------------
#Diametro promedio segun la especie
ggplot(database %>% group_by(especie) %>% 
         summarise(diametroPromedio = mean(diametro)), aes(x = especie, y = diametroPromedio)) +
  theme_ipsum() +
  geom_count(stat="identity", col = "#6c0000", size = 8) +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("DIAMETRO DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Diametro promedio en cm")

# Boxplot diametro en funcion de la especie
database %>%
  ggplot( aes(x=especie, y=diametro)) +
  geom_boxplot(color="#000000", fill="#732c4e", alpha=0.4) +
  scale_fill_viridis(discrete = TRUE, alpha=0.6, option="A") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11)
  ) +
  ggtitle("DIAMETRO DE LOS ARBOLES, BUENOS AIRES 2011") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  xlab("Especie") + ylab("Diametro en cm") + coord_flip()

#Histograma para ver la cantidad de arboles segun su diametro
database %>%
  ggplot(aes(x = diametro)) +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  geom_histogram(binwidth = 10, boundary = 0, fill="#69b3a2", color="#e9ecef", alpha=0.9)+
  ggtitle("DIAMETRO DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Diametro en cm") + ylab("Cantidad de arboles") +
  scale_y_continuous(limits = c(0, 80), breaks = seq(0, 80, by = 20)) +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(0, 160, by = 10))

cbind(table(diametro)) #test

#Poligono de frecuencia relativa para acompañar el histograma
tablaDiametro <- cbind(table(cut(diametro, seq(0, 160, by = 10), right = FALSE)))
relTablaDiametro <- tablaDiametro[,1]/length(diametro)
newDataFrame <- as.data.frame(relTablaDiametro)
newDataFrame

newDataFrame %>%
  ggplot( aes(x = seq(0, 150, by = 10), y = relTablaDiametro))  +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("DIAMETRO DE LOS ARBOLES, BUENOS AIRES 2011") +
  geom_freqpoly(stat = "identity") +
  xlab("Diametro en cm") + ylab("Frecuencia relativa") + 
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(-5, 155, by = 10), limits = c(-5, 155), labels = seq(0, 160, by = 10))


#Poligono de frecuencia relativa acumulada para acompañar el histograma
database %>%
  ggplot(aes(x=diametro)) + 
  geom_line(stat = "ecdf") +
  theme_ipsum() +
  theme(
    legend.position="none",
    plot.title = element_text(hjust=0.5,size=11),
    panel.grid.minor = element_blank(),
  ) +
  ggtitle("DIAMETRO DE LOS ARBOLES, BUENOS AIRES 2011") +
  xlab("Diametro en cm") + ylab("Frecuencia relativa acumulada") +
  labs(caption = "Fuente: Censo Forestal Urbano Publico") +
  scale_x_continuous(breaks = seq(0, 160, by = 10), limits = c(0, 160))

#Others ----------------------------
#Circular plot inclinacion en funcion de la altura
database %>%
  ggplot(aes(x = as.factor(altura), y = inclinacion)) +
  
  # This add the bars with a blue color
  geom_bar(stat="identity", fill=alpha("blue", 0.3)) +
  
  # Limits of the plot = very important. The negative value controls the size of the inner circle, the positive one is useful to add size over each bar
  ylim(-100,120) +
  
  # Custom the theme: no axis title and no cartesian grid
  theme_minimal() +
  theme(
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    plot.margin = unit(rep(-2,4), "cm")     # This remove unnecessary margin around plot
  ) +
  coord_polar(start = 0)
