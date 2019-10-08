/* Rexx program
   Acorns2QIF.rex
   
   Base code    02/14/2019
   Revision 1   02/14/2019
   Revision 2   02/15/2019
   Revision 3   02/17/2019
   Revision 4   09/07/2019
   Revision 5   10/07/2019

   This program will be used to read a monthly Acorns report. The report
   originates as a PDF file. We use Acrobat reader to export the file as
   a text file that we can then process as a file object.

   Version was a substantial rewrite due to chages in the text file that was
   being created out of Adobe Reader. The changes occured in how the buy
   transactions were being written out to the text file.   
   
*/ 

/*
   Define some search strings and their length for use further down in the
   code. These could change over time so we have to keep an eye on the 
   Acorns Report. Could also have an issue if the security name(s) should 
   change. 
*/

FormFeed = ''
Blanks = '     '
lenBlanks = length(Blanks)

SrchStr1 = 'Securities Bought'
lenSrchStr1 = length(SrchStr1)

SrchStr2 = 'Total Securities Bought'
lenSrchStr2 = length(SrchStr2)

SrchStr3 = 'Acorns Securities, LLC — Member FINRA/SIPC'
lenSrchStr3 = length(SrchStr3)

SrchStr4 = 'Page'
lenSrchStr4 = length(SrchStr4)

SrchStr5 = 'Vanguard FTSE Developed Markets ETF'
lenSrchStr5 = length(SrchStr5)

/*
   Get the names of the input/output files.  Output file should be a QIF file
   so that Quicken will recognize the file for import.
*/

say 'Input file name:'
pull FileInName
say 'Output file name:'
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

   Create handles for our securities mapping files.                          */

inAcornSecurities = .stream~new('AcornSecurities.txt')
inQuickenSecurities = .stream~new('QuickenSecurities.txt')

/* Open up the security mapping files.                                       */

inAcornSecurities~open('READ')
inQuickenSecurities~open('READ')

/*
   Read entries from the Acorns Securities file and load them into the
   pdfSec. stem variable.
*/

signal on notready name endAcorns

countAcorns = 0

do forever
  inBuff=inAcornSecurities~linein
  countAcorns = countAcorns + 1
  pdfSec.countAcorns = strip(inBuff,'B')
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
  quiSec.countQuicken = strip(inBuff,'B')
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
    say 'Number of securities that will be mapped is' NumSecurities
  end
else
  do
    say 'Number of securities in the mapping files does not match'
    say 'Acorns =' countAcorns '    Quicken =' countQuicken
    exit
  end
  
/* Open up both the input and output files.                                  */

inTXTfile~open('READ')
ouQIFfile~open('REPLACE')

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

/*
   The first line that we output to the file will tell Quicken what type
   of QIF file is being imported. The DO loop is used to go through each 
   buy transaction that is in our STEM variable TransBuy and create a 
   multiline output for each transaction.
   
   We had to introduce the boolSrchStr5 boolean variable to help control line
   reads from the txt file. The process of converting the Acorn PDF report file
   creates an extra line that is the security symbol. For one particular secu-
   rity this causes the symbol to be output at the end of the security infor-
   mation due to line wrap in the PDF file.  This is a crude fix and could be
   an issue in the future.
*/

ouQIFfile~lineout('!Type:Invst')

TransCount = 0
boolSrchStr5 = 0

do forever

  inBuff=strip(inTXTfile~linein)
  
/*
  Use screening statements to process in the bought security data.
*/

  if substr(inBuff,1,lenSrchStr2) = SrchStr2 then leave
  
  if substr(inBuff,1,1) = FormFeed | ,
     substr(inBuff,1,lenBlanks) = Blanks | ,
     substr(inBuff,1,lenSrchStr4) = SrchStr4 then iterate
     
  if substr(inBuff,1,lenSrchStr3) = SrchStr3 then
    do
      do skipLines = 1 to 10
        inBuff=strip(inTXTfile~linein)
      end skipLines
      iterate
    end

/*
  Use the builtin verify function to identify dates. We take the conttents of
  inBuff and chck to be sure the only characters observed are 0123456789 and /
  which would make up a date. If those are the only characters observed the
  function will return 0.
*/

  if verify(inBuff,'0123456789/') = 0 then
  
    do
      TransDate = 'D' || inBuff
      inBuff = strip(inTXTfile~linein)
      inBuff = strip(inTXTfile~linein)
      Security = strip(inTXTfile~linein)
      
      if substr(Security,1,lenSrchStr5) \= SrchStr5 then
      
        do
          PosLParen = pos('(',Security) - 2
          Security = substr(Security,1,PosLparen)
        end
      else
        boolSrchStr5 = 1
        
    end 

/* Map the security from the PDF/TXT file to the Quicken recognized security */

  do KK = 1 to 6
    if Security = pdfSec.KK then
      Security = quiSec.KK
  end KK
  
  MyBuy = 'NBuyx'
  Security = 'Y' || Security
  myQuantity = 'Q' || strip(inTXTfile~linein)
  myPrice = strip(inTXTfile~linein)
  myPrice = 'I' || strip(MyPrice,'L','$')
  myAmount = strip(inTXTfile~linein)
  myAmount1 = 'T' || strip(MyAmount,'L','$')
  myAmount2 = 'U' || strip(MyAmount,'L','$')
  myAmount3 = '$' || strip(MyAmount,'L','$')
  
  ouQIFfile~lineout(TransDate)
  ouQIFfile~lineout(MyBuy)
  ouQIFfile~lineout(Security)
  ouQIFfile~lineout(myPrice)
  ouQIFfile~lineout(myQuantity)
  ouQIFfile~lineout('O$0.00')
  ouQIFfile~lineout('L[WJM - Acorns-Cash]')
  ouQIFfile~lineout(myAmount1)
  ouQIFfile~lineout(myAmount2)
  ouQIFfile~lineout(myAmount3)
  ouQIFfile~lineout('^')

/* Execute following only when we detected a line wrap condition earlier in
   our code.
*/
   
  if boolSrchStr5 then
    do
      inbuff = inTXTfile~linein
      boolSrchStr5 = 0
    end

  TransCount = TransCount + 1
 
end

eofAllDone:

say TransCount 'buy transactions were processed.'

inTXTfile~close
ouQIFfile~close

exit
