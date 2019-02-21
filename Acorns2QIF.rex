/* Rexx program
   Acorns2QIF.rex
   
   Base code	02/14/2019
   Revision 1	02/14/2019
   Revision 2	02/15/2019
   Revision 3   02/17/2019

   This program will be used to read a monthly Acorns report. The report
   originates as a PDF file. We use Acrobat reader to export the file as
   a text file that we can then process as a file object.   
   
*/ 

/*
   Define some search strings and their lenght for use further down in the
   code. These could change over time so we have to keep an eye on the 
   Acorns Report. Could also have an issue if the security name(s) should 
   change. 
*/

SrchStr1 = "Securities Bought"
lenSrchStr1 = length(SrchStr1)
SrchStr2 = "Total Securities Bought"
lenSrchStr2 = length(SrchStr2)
SrchStr3 = "Acorns Securities, LLC — Member FINRA/SIPC"
lenSrchStr3 = length(SrchStr3)
SrchStr4 = "Bought"
lenSrchStr4 = length(SrchStr4)
SrchStr5 = "Vanguard FTSE Developed Markets ETF"
lenSrchStr5 = length(SrchStr5)

/*
   Get the names of the input/output files.  Output file should be a QIF file
   so that Quicken will recognize the file for import.
*/

say "Input file name:"
pull FileInName
say "Output file name:"
pull FileOutName

/* Create handles for our input and output files.                            */

inTXTfile = .stream~new(FileInName)
ouQIFfile = .stream~new(FileOutName)

/*
   We will read two files that contain security names. We had to do this
   because the security name in the Acorns file is an abbreviated name of the
   actual name that Quicken utilizes. Not all entries have to be translated,
   but we have all entries defined to keep the logic straight forward. These
   files may have to be updated if the underlying securities change.

/* Create handles for our securities mapping files.                          */

inAcornSecurities = .stream~new('AcornSecurities.txt')
inQuickenSecurities = .stream~new('QuickenSecurities.txt')

/* Open up the security mapping files.                                       */

inAcornSecurities~open("READ")
inQuickenSecurities~open("READ")

/*
   Read entries from the Acorns Securities file and load them into the
   pdfSec. stem variable.
*/

signal on notready name endAcorns
countAcorns = 0

do forever
  inBuff=inAcornSecurities~linein
  countAcorns = countAcorns + 1
  pdfSec.countAcorns = strip(inBuff,"B")
end

endAcorns:

inAcornSecurities~close

/*
   Read entries from the Quicken Securities file and load them into the
   quiSec. stem variable.
*/

signal on notready name endQuicken
countQuicken = 0

do forever
  inBuff=inQuickenSecurities~linein
  countQuicken = countQuicken + 1
  quiSec.countQuicken = strip(inBuff,"B")
end

endQuicken:

inQuickenSecurities~close

/*
   Check the record count from each of the security files. The count
   should match. If it doesn't then we issue a message and halt the
   execution.
*/

if countAcorns = countQuicken then
  do
    NumSecurities = countAcorns
    say "Number of securities that will be mapped is" NumSecurities
  end
else
  do
    say "Number of securities in the mapping files does not match"
    say "Acorns =" countAcorns "    Quicken =" countQuicken
    exit
  end
  
/* Open up both the input and output files.                                  */

inTXTfile~open("READ")
ouQIFfile~open("REPLACE")

/* We will use the signal directive to catch any errors and handle them.     */

signal on notready name eofAllDone

/* Loop through the input file looking for the securities bought section     */

do forever
  inBuff=inTXTfile~linein
  if substr(inBuff,1,lenSrchStr1) = SrchStr1 then leave
end

/*
   Next DO loop isolates only those lines which detail a bought security.
   We screen off all other lines. Currently the description of one of the 
   securities stradles two lines and we handle that the last if statement.
   When that situation occurs, we read the next two lines and then put the
   three pieces together. All of the lines are saved in the TransBuy STEM
   variable.
*/

TransCount = 0

do forever

  inBuff=inTXTfile~linein
  if substr(inBuff,1,lenSrchStr2) = SrchStr2 then leave
  if substr(inBuff,1,lenSrchStr3) = SrchStr3 then iterate
  if wordpos(SrchStr4,inBuff) \= 3 then iterate

  if pos(SrchStr5,inBuff,1) \= 0 then
    do
      inBuff1=inTXTfile~linein
      inBuff2=inTXTfile~linein
      inBuff = inBuff inBuff1 inBuff2
    end
    
  TransCount = TransCount + 1
  TransBuy.TransCount = inBuff
  
end

/*
   The first line that we output to the file will tell Quicken what type
   of QIF file is being imported. The DO loop is used to go through each 
   buy transaction that is in our STEM variable TransBuy and create a 
   multiline output for each transaction.
*/

ouQIFfile~lineout("!Type:Invst")

do JJ = 1 to TransCount

  parse var TransBuy.JJ TransDate . . OtherInfo
  PosLParen = pos("(",OtherInfo) - 2
  Security =strip(substr(OtherInfo,1,PosLParen),'B')
  PosRParen = pos(")",OtherInfo) + 2
  Pricing = substr(OtherInfo,PosRParen,30)
  parse var Pricing myQuantity myPrice myAmount
  myPrice = strip(myPrice,"L","$")
  myAmount = strip(myAmount,"L","$")

  do KK = 1 to 6
    if Security = pdfSec.KK then
      Security = quiSec.KK
  end

  sayL.1 = "D" || TransDate
  sayL.2 = "N" || "Buyx"
  sayL.3 = "Y" || Security
  sayL.4 = "I" || myPrice
  sayL.5 = "Q" || myQuantity
  sayL.6 = "O" || "$0.00"
  sayL.7 = "L" || "[WJM - Acorns-Cash]"
  sayL.8 = "T" || myAmount
  sayL.9 = "U" || myAmount
  sayL.10 = "$" || myAmount
  sayL.11 = "^"
  
  do KK = 1 to 11
    ouQIFfile~lineout(sayL.KK)
  end 
  
end

/*
   We will end up here when we have output all of the transactions to
   our file, or we encountered some type of error.
*/

eofAllDone:

inTXTfile~close
ouQIFfile~close

exit