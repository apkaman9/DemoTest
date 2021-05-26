/****** Object:  StoredProcedure [dbo].[usp_DM_MPF_Loan_2]    Script Date: 5/23/2018 1:58:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*  
------------------------------------------------------------------------------------------------------------  
Object: usp_DM_MPF_Loan_2  
------------------------------------------------------------------------------------------------------------  
Version          Date            Author                 Description
------------------------------------------------------------------------------------------------------------
Data Mart       09/30/2008       Shishir B            Object created for DM Project, This SP is executed 
	                                                to create the Datamart File DM_MPF_Loan_2_XX.txt where XX is the HLBName
Data Mart 2.0	07/22/2009		Kirti Chandra Sahu		TFS ID 2997 - Added 10 New LPR Fields
Data Mart 3.1   12/10/2009      S N Lakkani             TFS ID  - Added 15 new fields as per the requirements for AMA regulatory release 
Data Mart 4.0   03/08/2010 		Rinku Mulchandani		TFS ID 3125 - Added new field for Levels 7.1 Adj. Factor changes
DataMart 10.0	03/11/2013		Shahid Patel			TFS#3683 :: Seattle project :: Display records for Seattle and filter out FNMA Data.
Datamart 11.0   06/03/2013      Nisha makwana			TFS#3726::AI:: Changed length of variable @MCOwner to 100
Datamart 11.0   06/05/2013      Nisha makwana			TFS#3726::AI:: Remove hard coded maxparticipation and optimize query by removing unwanted replace expression.
DataMart 11.0	06\11\2013		Ajinkya Korade			TFS#3726 :: AI Phase1 :: Declared variable @Orgkey
DataMart 11.0	10/11/2013		Ajinkya Korade			TFS#4025 :: Undo Seattle :: Removed Seattle Conditions
DataMart XFund	05/13/2013		Shahid Patel			TFS#3748 :: MPF Xtra Funding
AIP2 DataMart	03/27/2015		Nitin Gupta				TFS#5832 :: Added new column LoanApplicationDate.
AI2 MCE			10/05/2015		Nitin Gupta				TFS#6763 :: Set NULL as default for LoanApplicationDate.
CE Realignment CR04 12/22/2015  Bhumika Sanghvi	        TFS#7111 :: Add two new columns CreditRatingSource & TragetEquivalentRating
BSR           01/18/2016		Ketan Chauhan			TFS#5889 :: Added new field EscrowIndicatorAtFunding, SRPPFIAmount,ServicingTypeKey, Master-InvestorServicer.
CE Realignment CR06	3/21/2016	Chandrashekhar			TFS#7111 :: Rename the column TargetEquivalentRating to TargetRatingEquivalent and change the select clause to select 'None' if 
														the value is not present.
ULDD P2         03/17/2016      Bhumika Sanghvi			TFS#7241 :: ULDD P2 :: Special Feature Code 7,8,9,10 Added
ULDD P2         03/24/2016      Bhumika Sanghvi			TFS#7241 :: ULDD P2 :: CoBorrower 2 & 3 Details Added
BSRCR1		    05/26/2016      Ketan Chauhan           TFS#7971 :: Added ISNULL Condition to the MasterInvestorServicer Field,  to show Lake view as Master Investor Servicer for Loans whose servicer is Prospect.
BSRCR1HF2       06/22/2016      Naser Barcham           TFS#7972 :: Modified the left join to select from the new DM_NonCashPaymentsHistory_LakeviewServicingData staging table
																	in MPFFHLBDW database instead of the NonCashPaymentsHistory_LakeviewServicingData staging table in LAS_Prod database 
																    where it was getting connected to via Application Server which was causing the TempDB size to increase and the EOD SSRS Reports to fail.
AG               6/15/2016       Aditi                   TFS#8086 :: Removed linked server refrence.														the value is not present.
BSRCR01_R5	   19/08/2016	    Ketan Chauhan		    TFS#8512 :: Added new field Total Esrow Amount Collected At Closing field in the end.
------------------------------------------------------------------------------------------------------------
*/

CREATE  PROCEDURE [dbo].[usp_DM_MPF_Loan_2] 
@HLBNumber INT  
AS  
-- TFS#3726::AI:: Changed length of variable @MCOwner to 100  
DECLARE @MCOwner varchar(100)  
--AI Phase 1 :: TFS : 3726 :: Declare @Orgkey which will store organization key for the HLBNumber passed as argument- Ajinkya Korade - 06\11\2013
DECLARE @OrgKey INT
SET @OrgKey=(SELECT OrgKey FROM [LOS_Prod].dbo.UV_FHLBankTableView WHERE HLBNumber=@HLBNumber)
SET @MCOwner = (SELECT Org.[Name]   
FROM [LOS_Prod].dbo.Org Org INNER JOIN   
 (SELECT  DISTINCT OrgKey   
  FROM [LOS_Prod].dbo.OrgServicingModelRole OSMR   
  WHERE RoleKey=1 AND DateTo IS NULL) OSMR   
 ON OSMR.OrgKEY=Org.OrgKEY  
WHERE Org.OrgKEY = @OrgKey)  
  
-- #7241-- Sets @HLBFlag to determine if HLB wants Decrypted or Encrypted data 
DECLARE @HLBFLag	bit

SELECT @HLBFlag = CASE WHEN Name = 'View DataMart Files as Encrypted' THEN 1 ELSE 0 END
FROM [LOS_Prod].dbo.[OrgRole] OrgRole
	INNER JOIN [LOS_Prod].dbo.[Role] R ON OrgRole.RoleKey = R.RoleKEY
WHERE OrgRole.OrgID = @HLBNumber
SET @HLBFLag = ISNULL(@HLBFLag,0) 
 
exec usp_OpenSymmetricKeys

BEGIN TRY 

--TFS#3726::AI::  optimize query by removing unwanted replace expression. 
SELECT loan.LoanNumber AS LoanNumber,  
replace(rtrim(replace((replace(rtrim(replace(pfi.PLLoanLevelCalculatedDownTo,0,' ')),' ',0)),'.',' ')),' ','.') AS PLLoanLevelCalculatedDownTo,
replace(rtrim(replace((replace(rtrim(replace(pfi.PLSMILoanLevelCoverage,0,' ')),' ',0)),'.',' ')),' ','.') AS PLSMILoanLevelCoverage,
'"' + ISNULL(Convert(varchar(200),pfi.PLAPLCategory),'') + '"' AS PLAPLCategory,   
'"' + ISNULL(Convert(varchar(200),pfi.PLHOEPAStatus),'') + '"' AS PLHOEPAStatus,  
'"' + ISNULL(Convert(varchar(200),pfi.PLLoanOriginationSource),'') + '"' AS PLLoanOriginationSource, 
replace(rtrim(replace((replace(rtrim(replace(pfi.PLMHLoanToInvoice,0,' ')),' ',0)),'.',' ')),' ','.') AS PLMHLoanToInvoice, 
'"' + ISNULL(Convert(varchar(200),pfi.PLMHNumberOfUnits),'') + '"' AS PLMHNumberOfUnits,   
'"' + ISNULL(Convert(varchar(200),pfi.PLMHPriorOccupancyStatus),'') + '"' AS PLMHPriorOccupancyStatus,   
'"' + ISNULL(Convert(varchar(200),pfi.PLMHYearBuilt),'') + '"' AS PLMHYearBuilt,   
replace(ltrim(replace(month(pfi.PLNoteDate),0,' ')) + '/' + ltrim(replace(day(pfi.PLNoteDate),0,' ')) + '/' + Convert(varchar(10),year(pfi.PLNoteDate)),' ',0) AS PLNoteDate, 
replace(rtrim(replace((replace(rtrim(replace(pfi.PLRateAPRSpread,0,' ')),' ',0)),'.',' ')),' ','.')AS PLRateAPRSpread, 
'"' + ISNULL(Convert(varchar(200),lch.LCSLCHCustodianID),'') + '"' AS LCSLCHCustodianID,   
Convert(varchar(200),lc.LCSLOCLetterOfCreditID) AS LCSLOCLetterOfCreditID,   
replace(ltrim(replace(month(lc.LCSLOCEffectiveDate),0,' ')) + '/' + ltrim(replace(day(lc.LCSLOCEffectiveDate),0,' ')) + '/' + Convert(varchar(10),year(lc.LCSLOCEffectiveDate)),' ',0) AS LCSLOCEffectiveDate, 
replace(ltrim(replace(month(lc.LCSLOCExpirationDate),0,' ')) + '/' + ltrim(replace(day(lc.LCSLOCExpirationDate),0,' ')) + '/' + Convert(varchar(10),year(lc.LCSLOCExpirationDate)),' ',0) AS LCSLOCExpirationDate,
Convert(DECIMAL(19,4),lc.LCSLOCLetterOfCreditAmount) AS LCSLOCLetterOfCreditAmount,
replace(ltrim(replace(month(lc.LCSLOCSettlementDate),0,' ')) + '/' + ltrim(replace(day(lc.LCSLOCSettlementDate),0,' ')) + '/' + Convert(varchar(10),year(lc.LCSLOCSettlementDate)),' ',0) AS LCSLOCSettlementDate,
Convert(varchar(200),lcloan.LCSLOCLIsRemovedFromLOC) AS LCSLOCLIsRemovedFromLOC,  
Convert(varchar(200),lsh.LCSLSHFinl01Flag)AS LCSLSHFinl01Flag,
replace(ltrim(replace(month(lsh.LCSLSHFINL01Date),0,' ')) + '/' + ltrim(replace(day(lsh.LCSLSHFINL01Date),0,' ')) + '/' + Convert(varchar(10),year(lsh.LCSLSHFINL01Date)),' ',0) AS LCSLSHFinl01Date,
'"' + ISNULL(Convert(varchar(200),smicert.SLCCertificateNbr),'') + '"' AS SLCCertificateNbr,  
replace(ltrim(replace(month(smicert.SLCUpdateDate),0,' ')) + '/' + ltrim(replace(day(smicert.SLCUpdateDate),0,' ')) + '/' + Convert(varchar(10),year(smicert.SLCUpdateDate)),' ',0) AS SLCUpdateDate,
--TFS ID 2997 - Kirti Sahu; Added 10 New LPR Fields  
 '"'+ REPLACE(pfi.FIPSCountyCode,'"','""') +'"' AS FIPSCountyCode,  
 '"'+ REPLACE(pfi.BorrowerFICOScoreSource,'"','""') +'"' AS BorrowerFICOScoreSource,  
 '"'+ REPLACE(pfi.CoBorrowerFICOScoreSource,'"','""') +'"' AS CoBorrowerFICOScoreSource,  
 --TFS#7241 :: ULDD P2 :: CoBorrower 2 & 3 Details Added
 '"'+ REPLACE(pfi.CoBorrower2FICOScoreSource,'"','""') +'"' AS CoBorrower2FICOScoreSource,  
 '"'+ REPLACE(pfi.CoBorrower3FICOScoreSource,'"','""') +'"' AS CoBorrower3FICOScoreSource,  
 '"'+ REPLACE(pfi.AUSCertificateNo,'"','""') +'"' AS AUSCertificateNo,  
 '"'+ REPLACE(pfi.LoanOriginatorID,'"','""') +'"' AS LoanOriginatorID,  
 '"'+ REPLACE(pfi.LoanOriginatorCompanyID,'"','""') +'"' AS LoanOriginatorCompanyID,  
 '"'+rtrim(ISNULL(REPLACE(pfi.HigherPricedMortgageLoanStatus,'"','""'),''))+'"' AS HigherPricedMortgageLoanStatus,  
	ISNULL(replace(rtrim(replace((replace(rtrim(replace(pfi.AveragePrimeOfferRateAPRSpread,0,' ')),' ',0)),'.',' ')),' ','.'),0) AS AveragePrimeOfferRateAPRSpread,
	'"'+ REPLACE(pfi.AppraiserStateLicenseNumber,'"','""') +'"' AS AppraiserStateLicenseNumber,
	'"'+ REPLACE(pfi.SupervisorAppraiserStateLicenseNumber,'"','""') +'"' AS SupervisorAppraiserStateLicenseNumber,
	replace(rtrim(replace((replace(rtrim(replace(CONVERT(DECIMAL(19,4),lfv.InvestorFeeAmount),0,' ')),' ',0)),'.',' ')),' ','.') AS InvestorFeeAmount,
--TFS ID 3108 - S N Lakakni - Added 15 new fields for AMA phase 2 drop 2
'"'+ REPLACE(pfi.SpecialHousingGoalsLoan,'"','""') +'"' AS SpecialHousingGoalsLoan,
'"'+ REPLACE(pfi.MortAcqFedFinStabFund ,'"','""') +'"' AS MortAcqFedFinStabFund,
'"'+ REPLACE(pfi.AppraisalDocumentFileIdentifier ,'"','""') +'"' AS AppraisalDocumentFileIdentifier,
'"'+ REPLACE(pfi.AffordableCategory1 ,'"','""') +'"' AS AffordableCategory1,
'"'+ REPLACE(pfi.AffordableCategory2 ,'"','""') +'"' AS AffordableCategory2,
'"'+ REPLACE(pfi.AffordableCategory3 ,'"','""') +'"' AS AffordableCategory3,
'"'+ REPLACE(pfi.AffordableCategory4 ,'"','""') +'"' AS AffordableCategory4,
'"'+ REPLACE(pfi.BorrowerRace2 ,'"','""') +'"' AS BorrowerRace2,
'"'+ REPLACE(pfi.BorrowerRace3 ,'"','""') +'"' AS BorrowerRace3,
'"'+ REPLACE(pfi.BorrowerRace4 ,'"','""') +'"' AS BorrowerRace4,
'"'+ REPLACE(pfi.BorrowerRace5 ,'"','""') +'"' AS BorrowerRace5,
'"'+ REPLACE(pfi.CoBorrowerRace2 ,'"','""') +'"' AS CoBorrowerRace2,
'"'+ REPLACE(pfi.CoBorrowerRace3 ,'"','""') +'"' AS CoBorrowerRace3,
'"'+ REPLACE(pfi.CoBorrowerRace4 ,'"','""') +'"' AS CoBorrowerRace4,
'"'+ REPLACE(pfi.CoBorrowerRace5 ,'"','""') +'"' AS CoBorrowerRace5,
--TFS#7241 :: ULDD P2 :: CoBorrower 2 & 3 Details Added
'"'+ REPLACE(pfi.CoBorrower2Race2 ,'"','""') +'"' AS CoBorrower2Race2,
'"'+ REPLACE(pfi.CoBorrower2Race3 ,'"','""') +'"' AS CoBorrower2Race3,
'"'+ REPLACE(pfi.CoBorrower2Race4 ,'"','""') +'"' AS CoBorrower2Race4,
'"'+ REPLACE(pfi.CoBorrower2Race5 ,'"','""') +'"' AS CoBorrower2Race5,
'"'+ REPLACE(pfi.CoBorrower3Race2 ,'"','""') +'"' AS CoBorrower3Race2,
'"'+ REPLACE(pfi.CoBorrower3Race3 ,'"','""') +'"' AS CoBorrower3Race3,
'"'+ REPLACE(pfi.CoBorrower3Race4 ,'"','""') +'"' AS CoBorrower3Race4,
'"'+ REPLACE(pfi.CoBorrower3Race5 ,'"','""') +'"' AS CoBorrower3Race5,
--TFS#7241 :: ULDD P2 :: CoBorrower 2 & 3 Details Added
	replace(rtrim(replace((replace(rtrim(replace(CONVERT(DECIMAL(19,4),pfi.CoBorrower2MonthlyIncome),0,' ')),' ',0)),'.',' ')),' ','.') AS CoBorrower2MonthlyIncome,
	'"'+ISNULL(REPLACE(pfi.CoBorrower2FICOScore,'"','""'),'')+'"' AS CoBorrower2FICOScore, 
	replace(rtrim(replace((replace(rtrim(replace(CONVERT(DECIMAL(19,4),pfi.CoBorrower3MonthlyIncome),0,' ')),' ',0)),'.',' ')),' ','.') AS CoBorrower3MonthlyIncome,
	'"'+ISNULL(REPLACE(pfi.CoBorrower3FICOScore,'"','""'),'')+'"' AS CoBorrower3FICOScore, 
	CASE
		WHEN @HLBFLag = 1
		THEN
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB( ISNULL(REPLACE(
			dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2Name,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') ,@HLBNumber))), 3, 8000))
		ELSE 
			'"'+ ISNULL(REPLACE(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2Name,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') +'"'
	END AS CoBorrower2Name, 
	CASE
		WHEN @HLBFLag = 1
		THEN
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB( ISNULL(REPLACE(
			dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3Name,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') ,@HLBNumber))), 3, 8000))
		ELSE 
			'"'+ ISNULL(REPLACE(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3Name,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') +'"'
	END AS CoBorrower3Name, 
	CASE
		WHEN @HLBFLag = 1
		THEN 
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB(ISNULL(REPLACE(
			dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2SSN,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') ,@HLBNumber))), 3, 8000))
		ELSE 
			'"'+ISNULL(REPLACE(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2SSN,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'')+'"'
	END AS CoBorrower2SSN,
	CASE
		WHEN @HLBFLag = 1
		THEN 
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB(ISNULL(REPLACE(
			dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3SSN,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'') ,@HLBNumber))), 3, 8000))
		ELSE 
			'"'+ISNULL(REPLACE(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3SSN,LTRIM(RTRIM(pfi.PFILoanNumber)),1),'"','""'),'')+'"'
	END AS CoBorrower3SSN,
	CASE WHEN pfi.CoBorrower2Race1 IS NULL THEN '"'+ltrim(rtrim(ISNULL(REPLACE(pfi.CoBorrower2Race1,'"','""'),'')))+'"' 
	ELSE '"'+ISNULL(REPLACE(pfi.CoBorrower2Race1,'"','""'),'')+'"' END AS CoBorrower2Race1, 
	CASE WHEN pfi.CoBorrower3Race1 IS NULL THEN '"'+ltrim(rtrim(ISNULL(REPLACE(pfi.CoBorrower3Race1,'"','""'),'')))+'"' 
	ELSE '"'+ISNULL(REPLACE(pfi.CoBorrower3Race1,'"','""'),'')+'"' END AS CoBorrower3Race1, 
	pfi.CoBorrower2Gender,
	pfi.CoBorrower3Gender,
	pfi.CoBorrower2Age,
	pfi.CoBorrower3Age,
	'"'+rtrim(ISNULL(REPLACE(pfi.SpecialFeatureCode7,'"','""'),''))+'"' AS SpecialFeatureCode7, 
	'"'+rtrim(ISNULL(REPLACE(pfi.SpecialFeatureCode8,'"','""'),''))+'"' AS SpecialFeatureCode8, 
	'"'+rtrim(ISNULL(REPLACE(pfi.SpecialFeatureCode9,'"','""'),''))+'"' AS SpecialFeatureCode9, 
	'"'+rtrim(ISNULL(REPLACE(pfi.SpecialFeatureCode10,'"','""'),''))+'"' AS SpecialFeatureCode10,
	CASE
		WHEN @HLBFLag = 1
		THEN 
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB(replace(ltrim(replace(month(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ ltrim(replace(day(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ Convert(varchar(10),year(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1))),' ',0),@HLBNumber))), 3, 8000))
		ELSE
			replace(ltrim(replace(month(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ ltrim(replace(day(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ Convert(varchar(10),year(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower2DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1))),' ',0) 
	END AS CoBorrower2DOBDate,
	CASE
		WHEN @HLBFLag = 1
		THEN 
			CONVERT(VARCHAR(MAX),'0x' + Substring(Upper(MASTER.dbo.Fn_varbintohexstr(dbo.udf_EncryptByHLB(replace(ltrim(replace(month(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ ltrim(replace(day(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ Convert(varchar(10),year(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1))),' ',0),@HLBNumber))), 3, 8000))
		ELSE
			replace(ltrim(replace(month(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ ltrim(replace(day(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1)),0,' ')) + '/' 
				+ Convert(varchar(10),year(dbo.udf_PII_AES_256_Decryption(pfi.CoBorrower3DOBDate,LTRIM(RTRIM(pfi.PFILoanNumber)),1))),' ',0) 
	END AS CoBorrower3DOBDate, 
	CASE WHEN pfi.CoBorrower2Ethnicity IS NULL THEN '"'+ ltrim(rtrim(ISNULL(REPLACE(pfi.CoBorrower2Ethnicity,'"','""'),''))) +'"' 
	ELSE '"'+ ISNULL(REPLACE(pfi.CoBorrower2Ethnicity,'"','""'),'') +'"' END AS CoBorrower2Ethnicity,
	CASE WHEN pfi.CoBorrower3Ethnicity IS NULL THEN '"'+ ltrim(rtrim(ISNULL(REPLACE(pfi.CoBorrower3Ethnicity,'"','""'),''))) +'"' 
	ELSE '"'+ ISNULL(REPLACE(pfi.CoBorrower3Ethnicity,'"','""'),'') +'"' END AS CoBorrower3Ethnicity,

--TFS ID 3125 - Added new Field for Levels 7.1 Adj. Factor changes
replace(rtrim(replace((replace(rtrim(replace(CONVERT(DECIMAL(19,4),pfi.UnadjustedCreditEnhancementForLoan),0,' ')),' ',0)),'.',' ')),' ','.') AS UnadjustedCreditEnhancementForLoan,
--AIP2 DataMart :: TFS#5832 :: Added new column LoanApplicationDate.
--TFS#6763 :: Set NULL as default for LoanApplicationDate.
NULL AS LoanApplicationDate,
--TFS#7111 :: Add two new columns CreditRatingSource & TragetEquivalentRating
--TFS#7111 :: CE CR06 :: change the select clause to select 'None' if the value is not present.
CASE
  WHEN (lla.CreditRatingSource IS NULL AND mc.MCProgramKey NOT IN (5,8,9) ) THEN '"S&P"' 
  ELSE (CASE WHEN lla.CreditRatingSource IS NULL THEN '"None"' ELSE  '"' + (lla.CreditRatingSource) + '"' END) END AS CreditRatingSource,
CASE
  WHEN (lla.TargetRatingEquivalent IS NULL AND mc.MCProgramKey NOT IN (5,8,9)) THEN '"AA"' 
  ELSE (CASE WHEN lla.TargetRatingEquivalent IS NULL THEN '"None"' ELSE  '"' + (lla.TargetRatingEquivalent) + '"' END) END AS TargetRatingEquivalent,

--TFS#7971 :: Added ISNULL Condition to the MasterInvestorServicer Field,  to show Lake view as Master Investor Servicer for Loans whose servicer is Prospect.
'"'+ ISNULL(REPLACE(LVSSD.InvestorServicerName,'"','""'), REPLACE(MTV.MasterInvestorServicer ,'"','""'))+'"' AS MasterInvestorServicer,
'"'+ REPLACE(MTV.ServicingType ,'"','""') +'"' AS ServicingType,
dml.EscrowIndicatorAtFunding AS EscrowIndicatorAtFunding,
lfv.SRPPFIAmount,
--TFS#8512 :: Added new field Total Esrow Amount Collected At Closing field in the end.
pfi.TotalEscrowAmountCollectedAtClosing
FROM [LOS_Prod].dbo.Loan loan 
LEFT OUTER JOIN (SELECT SMC.MANUMBER, SMC.Maxparticipationpercent AS Participation FROM dbo.DM_Select_MCCriteria SMC where ParticipationOrgKey=@OrgKey) LoanPart   
on loan.MANumber = LoanPart.MANumber  
LEFT OUTER JOIN UV_LCS_LoanCustodianHistory lch ON lch.LCSLCHLoanNumber = loan.LoanNumber AND lch.LCSLCHEndDate IS NULL  
--TFS#8086 -Aditi Dubey  Removed linked server refrence 
LEFT OUTER JOIN [LAS_Prod].[dbo].SMILoanCertificateNumber smicert ON smicert.SLCLoanNbr = loan.LoanNumber  
LEFT OUTER JOIN [LOS_Prod].dbo.MasterCommitment mc ON mc.MasterCommitmentID = loan.MANumber  
LEFT OUTER JOIN [LOS_Prod].dbo.MCModelType MT ON MC.MCModelTypeKey=MT.MCModelTypeKey  
LEFT OUTER JOIN [LOS_Prod].dbo.PFILoan pfi ON pfi.PFINumber = loan.PFINumber AND pfi.PFILoanNumber = loan.PFILoanNumber   
--TFS#8086 -Aditi Dubey  Removed linked server refrence 
LEFT OUTER JOIN [LCS_Prod].dbo.LCS_LetterOfCreditLoan lcloan ON lcloan.LCSLOCLLoanNumber = loan.LoanNumber   
LEFT OUTER JOIN [LCS_Prod].dbo.LCS_LetterOfCredit lc ON lc.LCSLOCLetterOfCreditID = lcloan.LCSLOCLLetterOfCreditID   
LEFT OUTER JOIN [LCS_Prod].dbo.LCS_LoanStatusHistory lsh ON lsh.LCSLSHLoanNumber = loan.LoanNumber   
LEFT OUTER JOIN [LOS_Prod].dbo.OrgPFI op ON mc.MCOriginatorOrgKEY = op.OrgKEY  
LEFT OUTER JOIN [LOS_Prod].dbo.Org o ON op.OrgKEY = o.OrgKey  
LEFT OUTER JOIN [LOS_Prod].dbo.LegacyLoanFundingView lfv ON lfv.LoanNumber = Loan.LoanNumber 
--AIP2 DataMart :: TFS#5832 :: Apply join to fetch LoanApplicationDate
LEFT OUTER JOIN DM_MPFLoan dml ON dml.LoanNumber = Loan.LoanNumber 
--CE Realignment CR04 ::TFS#7111 :: Apply join to fetch CreditRatingSource & TargetEquiavlentRating
LEFT OUTER JOIN UV_LoanLevelsAttributes lla ON  lla.PfiNumber = loan.PFINumber AND lla.PFILoanNumber = loan.PFILoanNumber
LEFT OUTER JOIN MasterCommitmentTableView MTV ON MTV.MANumber = loan.MANumber
--TFS#7971 :: Added Left Join to fetch InvestorServicerName from  NonCashPaymentsHistory_LakeviewServicingData whose servicer is Prospect.
LEFT OUTER JOIN (
 SELECT DISTINCT NCPHLoanNbr,
     InvestorServicerName
--TFS#7972 :: Changed the Staging table in LAS_Prod db to Staging table in MPFFHLBDW db.
 FROM DM_NonCashPaymentsHistory_LakeviewServicingData
 ) LVSSD
 ON LVSSD.NCPHLoanNbr = loan.LoanNumber
WHERE (mc.MCOwner = ltrim(rtrim(@MCOwner)) OR (LoanPart.Participation >0) )
-- Undo Seattle :: TFS : 4025 :: removed condition OR (@HLBNumber <> 10 AND LoanPart.Participation >0 ) - Ajinkya Korade - 10/11/2013
AND lfv.LoanfundingNumber = (SELECT TOP 1 LoanFund.LOANFUNDINGNUMBER FROM [LOS_Prod].dbo.LegacyLoanFundingView LoanFund WHERE LoanFund.LOANNUMBER = Loan.LoanNumber   ORDER BY LoanFund.ENTRYTIME DESC)
AND MT.ServicingModelKEY NOT IN (2,4)   
ORDER BY loan.LoanNumber 

END TRY  
 

BEGIN CATCH  
 PRINT 'Error retrieving data'  
END CATCH  

 EXEC usp_CloseSymmetricKeys

GO
