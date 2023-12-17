# IV Quadratic Fit with respect to Moneyness of an option (Sticky Delta)

# Basic Libraries needed

library(dplyr)
library(RND)
library(derivmkts)

#Parameter Library - A file to contain all the quadratic coefficients
ParameterLib <- data.frame(EXPIRY_DT = character(),a0 = numeric(), a1 = numeric(), a2 = numeric())

#Price file contains NIFTY option settlement prices for 15-DEC-2025
PriceFile <- read.csv("NIFTY.csv",stringsAsFactors = F)
PriceFile <- PriceFile[,c("TIMESTAMP","INSTRUMENT","SYMBOL","EXPIRY_DT","STRIKE_PR","OPTION_TYP",
                          "SETTLE_PR","CONTRACTS")]

#Rate assumed to be 7%
Rate <- 0.07

#Spot Price of NIFTY by Expiry date have been computed from the three available Futures prices
FutFile <- PriceFile[PriceFile$INSTRUMENT=="FUTIDX",]
FutFile$EXPIRY_DT<-as.Date(FutFile$EXPIRY_DT,"%m/%d/%Y")
FutFile$TIMESTAMP<-as.Date(FutFile$TIMESTAMP,"%m/%d/%Y")
FutFile$TIME_TO_EXP<-as.numeric(FutFile$EXPIRY_DT-FutFile$TIMESTAMP)/365
FutFile$INDEX_VAL<-FutFile$SETTLE_PR / exp(- Rate * FutFile$TIME_TO_EXP)


PriceFile$EXPIRY_DT<-as.Date(PriceFile$EXPIRY_DT,"%m/%d/%Y")
PriceFile$TIMESTAMP<-as.Date(PriceFile$TIMESTAMP,"%m/%d/%Y")
PriceFile<-merge(PriceFile,FutFile[,c("EXPIRY_DT","INDEX_VAL")],by="EXPIRY_DT",all.x = T)
PriceFile<-PriceFile[!is.na(PriceFile$INDEX_VAL),]
PriceFile<-PriceFile[PriceFile$OPTION_TYP != "FF",]

#Time to Expiry Computation
PriceFile$TIME_TO_EXP <- as.numeric((PriceFile$EXPIRY_DT - PriceFile$TIMESTAMP)/365)
PriceFile$IV <- 0

#Liquid and Illiquid prices are interpreted as containing higher and lower than the median traded contracts
LiquidPrice<-PriceFile[PriceFile$CONTRACTS >= median(PriceFile$CONTRACTS),]
IlliquidPrice<-PriceFile[PriceFile$CONTRACTS < median(PriceFile$CONTRACTS),]

#Only OTM Liquid Contracts are used
OTMCallPrice <- LiquidPrice$OPTION_TYP == "CE" & LiquidPrice$STRIKE_PR > LiquidPrice$INDEX_VAL
OTMPutPrice <- LiquidPrice$OPTION_TYP == "PE" & LiquidPrice$STRIKE_PR < LiquidPrice$INDEX_VAL

OTMLiquidPrice <- LiquidPrice[OTMCallPrice | OTMPutPrice,]

#A simple for loop to derive IV using 'derivmkts' package
for(i in 1:nrow(OTMLiquidPrice)){
  
  OTMLiquidPrice$IV[i] <- ifelse(OTMLiquidPrice$OPTION_TYP[i] == "CE",
                              bscallimpvol(OTMLiquidPrice$INDEX_VAL[i],
                                           OTMLiquidPrice$STRIKE_PR[i],
                                           Rate,OTMLiquidPrice$TIME_TO_EXP[i],0,
                                           OTMLiquidPrice$SETTLE_PR[i]),
                              bsputimpvol(OTMLiquidPrice$INDEX_VAL[i],
                                          OTMLiquidPrice$STRIKE_PR[i],
                                          Rate,OTMLiquidPrice$TIME_TO_EXP[i],0,
                                          OTMLiquidPrice$SETTLE_PR[i])
  )
  
}

#With the segregation criteria of Liquidity and OTM strikes, all Options should now have a valid IV
#In case there are any strikes for which IV could not be calculated, the matter shall need investigation
countViolations<-nrow(OTMLiquidPrice[OTMLiquidPrice$IV == "Option price violates minimum bound",])

LiquidPrice$IV<-NULL

LiquidPrice <- merge(LiquidPrice,OTMLiquidPrice[,c("EXPIRY_DT","STRIKE_PR","IV")],
                     by=c("EXPIRY_DT","STRIKE_PR"),all.x = T)
LiquidPrice <- LiquidPrice[!is.na(LiquidPrice$IV),]

#Add the new parameter of Moneyness - which is Strike/Spot
LiquidPrice$MONEYNESS <- LiquidPrice$STRIKE_PR / LiquidPrice$INDEX_VAL

PriceFile$MONEYNESS <- PriceFile$STRIKE_PR / PriceFile$INDEX_VAL

#A simple for loop that shall compute the quadratic coefficient to fit a curve using Liquid Strike IV
#The same coefficients were then used to compute IV for all Strikes
for(i in unique(LiquidPrice$EXPIRY_DT)){
  
  vol <-  LiquidPrice$IV[LiquidPrice$EXPIRY_DT == i]
  MONEYNESS <- LiquidPrice$MONEYNESS[LiquidPrice$EXPIRY_DT == i]
  tmp <- fit.implied.volatility.curve(vol,MONEYNESS)
  PriceFile$IV[PriceFile$EXPIRY_DT == i] <- tmp$a0 + 
    tmp$a1 * PriceFile$MONEYNESS[PriceFile$EXPIRY_DT == i] +
    tmp$a2 * PriceFile$MONEYNESS[PriceFile$EXPIRY_DT == i] ^ 2
  
  ParameterLib[nrow(ParameterLib)+1,] <- c(i,tmp$a0,tmp$a1,tmp$a2)
  
}

#A sample plot to Visually verify the smirk behavior of IV curve
SamplePlot <- PriceFile[PriceFile$EXPIRY_DT == '2023-12-28' & PriceFile$OPTION_TYP == "CE",]
plot(SamplePlot$MONEYNESS,SamplePlot$IV)

PriceFile <- PriceFile[,c("TIMESTAMP","INSTRUMENT","SYMBOL","EXPIRY_DT","STRIKE_PR","OPTION_TYP","SETTLE_PR",
               "INDEX_VAL","TIME_TO_EXP","MONEYNESS","IV")]

write.csv(PriceFile,"IV_StickyDelta.csv",row.names = F)
write.csv(ParameterLib,"CurveFit_Parameters.csv",row.names = F)
