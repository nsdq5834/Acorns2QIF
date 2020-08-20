/* Rexx program
   Acorns2QIF.rex
   
   Base code    02/14/2019
   Revision 1   02/14/2019
   Revision 2   02/15/2019
   Revision 3   02/17/2019
   Revision 4   09/07/2019
   Revision 5   10/07/2019
   Revision 6   07/24/2020
   Revision 7   08/19/2020

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
lenFF = length(FormFeed)

Blanks = ' '
lenBlanks = length(Blanks)

SS01 = 'Securities Bought'
lenSS01 = length(SS01)

SS02 = 'Total Securities Bought'
lenSS02 = length(SS02)

SS03 = 'Acorns Securities, LLC'
lenSS03 = length(SS03)

SS04 = 'Page'
lenSS04 = length(SS04)

SS05 = 'Vanguard FTSE Developed Markets ETF'
lenSS05 = length(SS05)

SS06 = 'William Meany' 
lenSS06 = length(SS06)

SS07 = 'Transactions' 
lenSS07 = length(SS07)

SS08 = 'Date'
lenSS08 = length(SS08)
 
SS09 = 'Settlement Date'
lenSS09 = length(SS09)
 
SS10 = 'Activity'
lenSS10 = length(SS10)
 
SS11 = 'Description'
lenSS11 = length(SS11)
 
SS12 = 'Quantity'
lenSS12 = length(SS12)
 
SS13 = 'Price'
lenSS13 = length(SS13)
 
SS14 = 'Amount'
lenSS14 = length(SS14)

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

/* Loop through the input file looking for the securities bought section     */

do label SkipProlog forever
  inBuff=strip(inTXTfile~linein)
  if left(inBuff,lenSS01) = SS01 then leave SkipProlog
end SkipProlog

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

do label OuterLoop forever

  inBuff=strip(inTXTfile~linein)
  if inBuff = "" then iterate OuterLoop

/* Look for the end of the bought transactions sections and exit the loop.   */
  
    if left(inBuff,lenSS02) = SS02 then leave OuterLoop
  
/*
  Use screening statements to process in the bought security data section.
*/

  if left(inBuff,lenSS03) = SS03 then
    do
	  inBuff=inTXTfile~linein
	  iterate OuterLoop
	end
	
    tempText='AfterSS03 =' inBuff
    ouDBUfile~lineout(tempText)	
	
  if substr(inBuff,1,lenFF) = FormFeed | ,
     substr(inBuff,1,lenBlanks) = Blanks | ,
     substr(inBuff,1,lenSS04) = SS04 | ,
	 substr(inBuff,1,lenSS06) = SS06 | ,
	 substr(inBuff,1,lenSS07) = SS07 | ,
	 substr(inBuff,1,lenSS08) = SS08 | ,
	 substr(inBuff,1,lenSS09) = SS09 | ,
	 substr(inBuff,1,lenSS10) = SS10 | ,
	 substr(inBuff,1,lenSS11) = SS11 | ,
	 substr(inBuff,1,lenSS12) = SS12 | ,
	 substr(inBuff,1,lenSS13) = SS13 | ,
	 substr(inBuff,1,lenSS14) = SS14 then
	   iterate OuterLoop

/*
  Use the builtin verify function to identify dates. We take the contents of
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
	  
      if substr(Security,1,lenSS05) \= SS05 then      
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
	  do
        Security = quiSec.KK
	    leave KK
	  end
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
      inBuff = inTXTfile~linein
      boolSrchStr5 = 0
    end

  TransCount = TransCount + 1
 
end OuterLoop

eofAllDone:

say TransCount 'buy transactions were processed.'

inTXTfile~close
ouQIFfile~close

exit
