/****** Object:  StoredProcedure [dbo].[usp_GetPairOffFeeInfo]    Script Date: 5/23/2018 1:58:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


/**** Procedure: [usp_GetPairOffFeeInfo]   **************************************************************************
*
* ---------------------------------------------------------------------------------------------------------------------
* Version					Date        Developer      TFS ID	Description
* ---------------------------------------------------------------------------------------------------------------------
* Report Migration SSRS  2009-11-27  Suryakant Chavan   3061	Stored Procedure to calculate the mannual reduction, expired reduction, Business day,
																remittence and pair of fee as per the DC date and DC Number for DC Pair of Fee report
* Reports Migration SSRS 2010-01-28		S N Lakkani     3061	Modified to retrieve the Current Pricing based on Current Schedules
* Reports Migration SSRS 2010-02-08		S N Lakkani     3061	Modified to incorporate 5 decimal places for the Rate fields
* Reports Migration SSRS 2010-02-08  suvarna aigal      3242    Modified to include PricingAdjustmentFactorFee to the filed Fees
* Reports Migration SSRS 2012-10-08  Ajinkya Korade	    3564    -Modified to retrieve ProductCode which will be used as one of the criteria to 
*																get the MPFBankPricingPortfolioAdjustmentFactor
*																-Added MinimumNoteRate criteria for LowestPricing Fee Selection								
*																-Added MaximumNoteRate criteria for HighestPricing Fee Selection								
*        					 									-Removed the �ReductionAmount > 0� check so that Fee is common for case when Delivery Commitment is overfunded and when it is not not.  
* Reports Migration SSRS 2013-01-14	Ajinkya Korade		3626	IBPP3 :: Made Changes for IBPP3
* 10.0															-Applied PFI Pricing Adjustment Factor to Lowest Pricing, highest Pricing and Current Pricing
*																-Passed on more parameter MPFBankID to udf_GetPairOffSchCode
*Datamart 11.0              2013-06-14       Nisha Makwana     TFS#3726::AI Phase I::Added Distinct clause in query to return single data.
**********************************************************************************************************************/
CREATE PROCEDURE [dbo].[usp_GetPairOffFeeInfo]
	@SHFDType CHAR(1),
	@sDCNumber int,
	@sCurrentPricing Decimal(30,8),
	--@sDCRate Decimal(30,8),
	@sReductionAmount decimal(30,2)
	
		
AS
BEGIN
	SET NOCOUNT ON;
	
	
 ---TFSID-3242 Added for retriving latest PricingadjustmentFee - Suvarna 2010-02-08     
     
    ---Retriving HLBNumber using DC Number    
    DECLARE @OwningMPFBankNumber INT     
    SELECT @OwningMPFBankNumber = o.OwningMPFBank     
    FROM [LOS_Prod].dbo.DeliveryCommitment dc inner join     
   [LOS_Prod].dbo.MasterCommitment mc on mc.MasterCommitmentKEY = dc.MasterCommitmentKEY inner join     
   [LOS_Prod].dbo.OrgPFI o on o.OrgKEY = mc.MCOriginatorOrgKey     
    where dc.DeliveryCommitmentID =@sDCNumber    
     
 ---TFS ID 3242-To pull the appropriate Adjustment Factor for the given MPF Bank -Suvarna Aigal 10/18/2010    
    DECLARE @CDate VARCHAR(10)    
	DECLARE @CTime VARCHAR(10)    
	DECLARE @DateToUse DATETIME    
	--Retrieve CurrentDate from CurrentDateTime table    
	SET @CDate = (SELECT CONVERT(VARCHAR(10),CurrentDateTime,101)     
	from [LOS_Prod].dbo.CurrentDateTime)    
	--Retrieve System Time    
	SET @CTime = (SELECT CONVERT(VARCHAR(10),GETDATE(),108))     
	SET @DateToUse=CONVERT(DATETIME,@CDate + ' ' + @CTime)    
    
    DECLARE @MPFBankPricngAdjustmentFactor decimal(11,10)    
    
    --[IBP] :: TFS:3564 : Added for retrieving ProductCode
	DECLARE @ProductCode VARCHAR(4)
	DECLARE @MaximumNoteRate Decimal(6,5)
	DECLARE @MinimumNoteRate Decimal(6,5)	
	SELECT @ProductCode=sch.ProductCode from [LOS_Prod].dbo.DeliveryCommitment dc 
	INNER JOIN  [LOS_Prod].dbo.Schedule sch ON dc.ScheduleCode=sch.ScheduleCode
	WHERE dc.DeliveryCommitmentID=@sDCNumber
	
	--[IBP] :: TFS:3564 : Modified to retrieve MaximumNoteRate and MinimumNoteRate
    SELECT TOP 1 @MPFBankPricngAdjustmentFactor = cast(MPFBankPricingPortfolioAdjustmentFactor as decimal)/10000
    ,@MaximumNoteRate=MaximumNoteRate
    ,@MinimumNoteRate=MinimumNoteRate  
	FROM  DM_MPF_Daily_Pricing_Adjustment_Factor PriAdjFac   
	WHERE MPFBankID = @OwningMPFBankNumber AND ProductCode = @ProductCode 
	AND EntryDateTime <= @DateToUse    
	ORDER BY EntryDateTime DESC 
----------------------------- 	
	--[IBPP3] :: TFS : 3626 :: Declare Variables @PFIBankPricingAdjustmentFactor and @PFINumber
    DECLARE @PFIBankPricingAdjustmentFactor decimal(11,10)
	DECLARE @PFINumber CHAR(6)
	
	--[IBPP3] :: get PFI Number  
	Select @PFINumber=o.OrgID FROM [LOS_Prod].dbo.DeliveryCommitment dc 
	INNER JOIN [LOS_Prod].dbo.MasterCommitment mc ON dc.MasterCommitmentKEY =mc.MasterCommitmentKEY
	INNER JOIN [LOS_Prod].dbo.Org o ON mc.MCOriginatorOrgKey=o.OrgKEY Where dc.DeliveryCommitmentID=@sDCNumber
	
	--[IBPP3] :: TFS : 3626 :: Get PFI Pricing Adjustment Factor 
	IF EXISTS(	SELECT * FROM  DM_MPF_Daily_PFI_Pricing_Adjustment_Factor PFIPriAdjFac   
			WHERE PFIPriAdjFac.PFINumber=@PFINumber AND ProductCode = @ProductCode 
			AND EntryDateTime <= @DateToUse    )    
		BEGIN
	--[IBP3] :: TFS :: 3626 :: Modified the columns	used to reflect changes made in the 'DM_MPF_Daily_PFI_Pricing_Adjustment_Factor' table.
		SELECT TOP 1 @PFIBankPricingAdjustmentFactor = cast(PricingAdjustmentFactor as decimal)/10000
			FROM  DM_MPF_Daily_PFI_Pricing_Adjustment_Factor PFIPriAdjFac   
			WHERE PFIPriAdjFac.PFINumber=@PFINumber AND ProductCode = @ProductCode AND ProductType = 'Portfolio'
			AND EntryDateTime <= @DateToUse    
			ORDER BY EntryDateTime DESC
		END
	ELSE
		BEGIN
		SET @PFIBankPricingAdjustmentFactor = 0
		END
	
	Declare @sPairOffFee decimal(30,2)
	Declare @sProductCode varchar(4)
	Declare @sNoteRate decimal(30,5)
	Declare @sDeliveryDate date
	Declare @sScheduleCode varchar(11)
	Declare @sAFee decimal(30,8)
	Declare @sCurrentRate decimal(30,8)
	Declare @sDeliveryAmount int
	Declare @sDCAmount int
	Declare @sFundedAmount int
	Declare @DeliveryStatus varchar(4)
	Declare @sScheduleType int
	Declare @sRemittanceTypeID int
	Declare @sTolerancePercent decimal(30,4)
	Declare @sToleranceAmount decimal(30,4)
	Declare @sOriginalDCAmount int
	Declare @DCTolerance decimal(30,4)
	Declare @sAFDifference decimal(30,8)
	Declare @sBalanceAtExpiration int
	Declare @dblDaysForward int
	Declare @dBusinessDaysOff date
	Declare @ScheduleToUse int
	Declare @fDCRate Decimal(30,8)
	Declare @sDCRate Decimal(30,8)
	
	Declare @sLRAFRate Decimal(30,8)
	Declare @sLRAFFee Decimal(30,5)
	Declare @sManualReductions decimal(30,2)
	Declare @sExpiredReductions decimal(30,2)
		
	
	Declare @sRemittanceTypeDescription varchar(5)
	Declare @boxReductionsDone decimal(30,2)
	Declare @boxDaysToExpiration varchar(50)
	Declare @sDCInterestNote varchar(150)
	Declare @boxProductType varchar(4)
	
	
	Declare @DeliveryCommitmentNumber int
	Declare @DCMessage varchar(100)

		
		
	
		--If (@sDCNumber >0) And (@sDCNumber <1000000000)
			
			--Begin
			If @SHFDType='Y' or @SHFDType='y'
			Begin
				 SELECT @DeliveryCommitmentNumber=DC.DeliveryCommitmentNumber, @sProductCode=SCHED.ProductCode, 
						@sNoteRate=Convert(Decimal(30,4),DC.NoteRate*100,0),@sDeliveryDate=DC.DeliveryDate,
						@sScheduleCode=DC.ScheduleCode,
						---TFS ID 3242-Modified RateFee by including PricingAdjFee- Suvarna Aigal 02/Dec/20101 
                        @sAFee=Convert(Decimal(30,8),(RATE.Fee + (CAST(DC.MPFBankPricingPortfolioAdjustmentFactor as decimal)/10000) 
                        + (CAST(DC.PFIBankPricingPortfolioAdjustmentFactor as decimal)/10000))*100,0), --[IBPP3] :: [TFS] : 3626 ::Applied PFIPricing adjustment Factor
						@sDeliveryAmount=DC.DeliveryAmount,@sFundedAmount=DC.FundedAmount,
						@DeliveryStatus=DC.DeliveryStatus,@sScheduleType=SCHED.ScheduleType,
						@sRemittanceTypeID=SCHED.RemittanceTypeID,@sTolerancePercent= DC.TolerancePercent,
						@sToleranceAmount=DC.ToleranceAmount, @sOriginalDCAmount=DC.OriginalDeliveryAmount
						FROM UV_Schedule_SHFD  AS SCHED INNER JOIN (UV_LoanRatesAgentFees_SHFD AS RATE 
					    INNER JOIN --TFS#3726::AI Phase I
                       (select distinct NoteRate,ScheduleCode,DeliveryCommitmentNumber,PFIBankPricingPortfolioAdjustmentFactor,DeliveryAmount,
                       DeliveryDate,FundedAmount,DeliveryStatus,TolerancePercent,OriginalDeliveryAmount,MPFBankPricingPortfolioAdjustmentFactor,
                       ToleranceAmount from UV_DeliveryCommitment_SHFD) AS DC ON (DC.NoteRate = RATE.Rate)  
        
					    AND (RATE.ScheduleCode = DC.ScheduleCode)) ON SCHED.ScheduleCode = RATE.ScheduleCode
					    WHERE DC.DeliveryCommitmentNumber= @sDCNumber 
			End
			Else
			Begin
				SELECT @DeliveryCommitmentNumber=DC.DeliveryCommitmentNumber, @sProductCode=SCHED.ProductCode, 
						@sNoteRate=Convert(Decimal(30,4),DC.NoteRate*100,0),@sDeliveryDate=DC.DeliveryDate,
						@sScheduleCode=DC.ScheduleCode,
						---TFS ID 3242-Modified RateFee by including PricingAdjFee- Suvarna Aigal 02/Dec/20101 
						@sAFee=Convert(Decimal(30,8),(RATE.Fee + (CAST(DC.MPFBankPricingPortfolioAdjustmentFactor as decimal)/10000) 
						+ (CAST(DC.PFIBankPricingPortfolioAdjustmentFactor as decimal)/10000))*100,0), --[IBPP3] :: [TFS] : 3626 ::Applied PFIPricing adjustment Factor    
						@sDeliveryAmount=DC.DeliveryAmount,@sFundedAmount=DC.FundedAmount,
						@DeliveryStatus=DC.DeliveryStatus,@sScheduleType=SCHED.ScheduleType,
						@sRemittanceTypeID=SCHED.RemittanceTypeID,@sTolerancePercent= DC.TolerancePercent,
						@sToleranceAmount=DC.ToleranceAmount, @sOriginalDCAmount=DC.OriginalDeliveryAmount
						FROM UV_Schedule_NOSHFD  AS SCHED INNER JOIN (UV_LoanRatesAgentFees_NOSHFD AS RATE 
					    INNER JOIN
					     --TFS#3726::AI Phase I
                      (select distinct NoteRate,ScheduleCode,DeliveryCommitmentNumber,PFIBankPricingPortfolioAdjustmentFactor,
                      DeliveryAmount,DeliveryDate,FundedAmount,DeliveryStatus,TolerancePercent,OriginalDeliveryAmount,
                      MPFBankPricingPortfolioAdjustmentFactor,ToleranceAmount from UV_DeliveryCommitment_NOSHFD) AS DC ON (DC.NoteRate = RATE.Rate)  
       
					    AND (RATE.ScheduleCode = DC.ScheduleCode)) ON SCHED.ScheduleCode = RATE.ScheduleCode
					    WHERE DC.DeliveryCommitmentNumber= @sDCNumber
			End		    
				Set @DCMessage = [dbo].[udf_CheckValidDCNumber](@SHFDType,@sDCNumber,'',@DeliveryCommitmentNumber,@DeliveryStatus)	
				
				SET @sDCRate = @sAFee 
				
				  
				
				If (@DCMessage='True')
					Begin
				---To calculate Manual reduction and Expired reduction
						Set @DCMessage=''
						Set @sManualReductions=0
						
						If @SHFDType='Y' or @SHFDType='y'
						Begin
							SELECT @sManualReductions=Sum(DCR.Reduction)
								FROM UV_DeliveryCommitmentReduction_SHFD as DCR
								GROUP BY DCR.DeliveryCommitmentNumber, DCR.TransactionCode 
								HAVING DCR.DeliveryCommitmentNumber = @sDCNumber and DCR.TransactionCode = 'dr01'	   
						End
						Else
						Begin
							SELECT @sManualReductions=Sum(DCR.Reduction)
								FROM UV_DeliveryCommitmentReduction_NOSHFD as DCR
								GROUP BY DCR.DeliveryCommitmentNumber, DCR.TransactionCode 
								HAVING DCR.DeliveryCommitmentNumber = @sDCNumber and DCR.TransactionCode = 'dr01'
						End
						
						
								
						If (@sManualReductions=0)
							Begin
								Set @sManualReductions=0.00
							End		
						Else
							Begin
								Set @sManualReductions=CONVERT(Money,@sManualReductions)
							End	
						
						Set @sExpiredReductions=0
						
						If @SHFDType='Y' or @SHFDType='y'
						Begin
								SELECT @sExpiredReductions=Sum(DCR.Reduction)
								FROM UV_DeliveryCommitmentReduction_SHFD as DCR
								GROUP BY DCR.DeliveryCommitmentNumber, DCR.TransactionCode 
								HAVING DCR.DeliveryCommitmentNumber = @sDCNumber and DCR.TransactionCode <> 'dr01'	   
						End
						Else
						Begin
								SELECT @sExpiredReductions=Sum(DCR.Reduction)
								FROM UV_DeliveryCommitmentReduction_NOSHFD as DCR
								GROUP BY DCR.DeliveryCommitmentNumber, DCR.TransactionCode 
								HAVING DCR.DeliveryCommitmentNumber = @sDCNumber and DCR.TransactionCode <> 'dr01'	   
						End		
											
												
						If (@sExpiredReductions=0)
							Begin
								Set @sExpiredReductions=0.00
							End		
						Else
							Begin
								Set @sExpiredReductions=CONVERT(Money,@sExpiredReductions)
							End		
						
						set @boxReductionsDone=CONVERT(Decimal(30,2),(@sManualReductions+@sExpiredReductions))
						
						----Reduction calculation done
						Set @boxProductType=@sProductCode
						
						
						--To get remittence description
						If @SHFDType='Y' or @SHFDType='y'
						Begin
							SELECT @sRemittanceTypeDescription=RT.ShortDescription FROM UV_RemittanceType_SHFD AS RT 
								WHERE RT.RemittanceTypeID =@sRemittanceTypeID
								GROUP BY RT.ShortDescription
						End
						Else
						Begin
							SELECT @sRemittanceTypeDescription=RT.ShortDescription FROM UV_RemittanceType_NOSHFD AS RT 
								WHERE RT.RemittanceTypeID =@sRemittanceTypeID
								GROUP BY RT.ShortDescription
						End		
						----------------------
						Set @DCTolerance= (@sTolerancePercent* @sOriginalDCAmount) --CONVERT(Money,(@sTolerancePercent* @sOriginalDCAmount))
						
						---Calculate Rate difference
						Set @sAFDifference = @sNoteRate - @sAFee
						Set @sDCAmount=Convert(Money,@sDeliveryAmount)
						Set @sBalanceAtExpiration = Convert(Money,@sDCAmount - @sFundedAmount)
								    		
				End	
					
			
						--Calculate the Business day on the basis DeliveryDate 
						
						if (Convert(date,@sDeliveryDate)) = (CONVERT(date,getdate()))
							Begin
								set @dblDaysForward=0
							End
						Else if (convert(date,@sDeliveryDate)) < (CONVERT(date,getdate()))
							Begin 
								set @dblDaysForward=0
							End
						Else if (convert(date,@sDeliveryDate))> (CONVERT(date,getdate()))
								Begin
							
									set @dblDaysForward=1
									set @dBusinessDaysOff=''
																					
									While convert(date,@dBusinessDaysOff) <> convert(date,@sDeliveryDate)
									Begin
										set @dBusinessDaysOff = dbo.udf_addBusinessDays(@dblDaysForward, CONVERT(date,getdate())) --To get next business day
										set @dBusinessDaysOff = dbo.udf_calcDateForBankHolidays(@SHFDType,convert(date,@dBusinessDaysOff)) --To check business day is holiday or not
										
										Set @dblDaysForward = @dblDaysForward + 1
										
									End
									
															
									Set @dblDaysForward = @dblDaysForward - 1
									
								End	
																
									If (@dblDaysForward>=0) and (@dblDaysForward<=5)
										Begin
											Set @ScheduleToUse=3
										End
									Else If (@dblDaysForward >=6) and (@dblDaysForward <=15)	
										Begin
											Set @ScheduleToUse=10
										End
									Else If (@dblDaysForward >=16) and (@dblDaysForward <=25)	
										Begin
											Set @ScheduleToUse=20
										End
									Else If (@dblDaysForward >=26) and (@dblDaysForward <=37)	
										Begin
											Set @ScheduleToUse=30
										End	
									Else If (@dblDaysForward >=38) and (@dblDaysForward <=100)	
										Begin
											Set @ScheduleToUse=45
										End	
										
									Set @boxDaysToExpiration=@dblDaysForward	
									
									-----To get the schedule code
									--[IBPP3] :: [TFS] : 3626 ::Passed one more parameter MPFBankID 
				set @sScheduleCode = dbo.udf_GetPairOffSchCode(@SHFDType,CONVERT(date,getdate()),@sProductCode,@ScheduleToUse,@sRemittanceTypeID,@OwningMPFBankNumber)
	
				-- S N Lakkani --> Logic to the get the current Pricing on the DC
				IF @sCurrentPricing = 0
				BEGIN
					DECLARE @CurrentDCRate decimal(30,5)
					IF @sNoteRate IS NOT NULL 
						SET @CurrentDCRate = (@sNoteRate / 100)
						
									
					IF @sScheduleCode != '0000000000'
					BEGIN 
					
						--TFS:3564 :: IBP-2 :: Variables to determine the Applicable Note Rates range while fetching Agent Fee from the
						--LoanRatesAndAgentFees
						DECLARE @MaximumRateLRAF			DECiMAL(6, 5) --Maximum Note Rate for the schedule from LoanRatesAgentFees
						DECLARE @MinimumRateLRAF			DECiMAL(6, 5) --Minimum Note Rate for the schedule from LoanRatesAgentFees
						DECLARE	@ApplicableMaximumNoteRate	DECiMAL(6, 5)
						DECLARE	@ApplicableMinimumNoteRate	DECiMAL(6, 5)
						
						--TFS:3564 :: IBP-2 :: Retrieve the Maximum and Minimum Note Rates from the LoanRatesAndAgentFees table for the Schedule
						iF @SHFDType = 'Y'
						BEGiN
							SELECT	@MaximumRateLRAF = MAX(LRAF.Rate),
									@MinimumRateLRAF = MiN(LRAF.Rate)
							FROM	UV_LoanRatesAgentFees_SHFD LRAF
							WHERE	LRAF.ScheduleCode = @sScheduleCode
						END
						ELSE
						BEGiN
							SELECT	@MaximumRateLRAF = MAX(LRAF.Rate),
									@MinimumRateLRAF = MiN(LRAF.Rate)
							FROM	UV_LoanRatesAgentFees_NOSHFD LRAF
							WHERE	LRAF.ScheduleCode = @sScheduleCode
						END
						
						
						--TFS:3564 :: IBP-2 :: Following iF condition validates if the Product Level Note Rate  range is NOT
						--outside of LoanRatesAgenFees range
						--Examples of out of range: TPM Range - 6% - 8%; Product Note Rate Range - 4% - 5% or 9% - 11%
						iF	NOT (@MaximumNoteRate < @MinimumRateLRAF OR @MinimumNoteRate > @MaximumRateLRAF)
						BEGiN

							--The following statement stores 
							--	the Maximum of the MinimumRate values and
							--	the Minimum of the MaximumRate values
							SELECT	@ApplicableMinimumNoteRate = 
										CASE WHEN @MinimumNoteRate < @MinimumRateLRAF
											THEN @MinimumRateLRAF
										ELSE
											@MinimumNoteRate
										END,
									@ApplicableMaximumNoteRate =
										CASE WHEN @MaximumNoteRate > @MaximumRateLRAF
											THEN @MaximumRateLRAF
										ELSE
											@MaximumNoteRate
										END
						END
						ELSE --iF the Product Level Note Rate Range is outside of the LoanRatesAgentFees range, then LoanRateAgentFees range applies
						BEGiN
							SELECT	@ApplicableMinimumNoteRate = @MinimumRateLRAF,
									@ApplicableMaximumNoteRate = @MaximumRateLRAF
						END


						IF @SHFDType = 'Y' OR @SHFDType = 'y'
						BEGIN
						 
							SET @sCurrentPricing = (SELECT LRAF.Fee FROM UV_LoanRatesAgentFees_SHFD AS LRAF 
													WHERE LRAF.ScheduleCode = @sScheduleCode And LRAF.RATE = @CurrentDCRate
													 --TFS:3564 :: IBP-2 :: Reduce the Scope of Rates to the extent allowable for the Product
													AND LRAF.Rate >= @ApplicableMinimumNoteRate AND LRAF.Rate <= @ApplicableMaximumNoteRate
													GROUP BY LRAF.Fee)
						END
						ELSE
						BEGIN
						
							SET @sCurrentPricing = (SELECT LRAF.Fee FROM UV_LoanRatesAgentFees_NOSHFD AS LRAF 
													WHERE LRAF.ScheduleCode = @sScheduleCode And LRAF.RATE = @CurrentDCRate 
													 --TFS:3564 :: IBP-2 :: Reduce the Scope of Rates to the extent allowable for the Product
													AND LRAF.Rate >= @ApplicableMinimumNoteRate AND LRAF.Rate <= @ApplicableMaximumNoteRate
													GROUP BY LRAF.Fee)
						END 
					END
					
					     ---TFS ID 3242-Modified RateFee by including PricingAdjFee- Suvarna Aigal 02/Dec/20101           
					     --[IBPP3] :: [TFS] : 3626 :: Applied PFIPricing Adjustment Factor
							 SET @sCurrentPricing = @sCurrentPricing +@MPFBankPricngAdjustmentFactor +@PFIBankPricingAdjustmentFactor   
       
       
					IF @sCurrentPricing IS NULL
					BEGIN
						DECLARE @lowestNoterate DECIMAL(30,5), @highestNoteRate DECIMAL(30,5), @lowestPricing DECIMAL(30,8), @highestPricing DECIMAL(30,8)
						
						IF @SHFDType = 'Y' OR @SHFDType = 'y'
						BEGIN
						--[IBP] :: TFS:3564 : Added MinimumNoteRate criteria for Fee Selection 
							SELECT TOP 1 @lowestPricing = LRAF.Fee, @lowestNoterate = LRAF.Rate FROM UV_LoanRatesAgentFees_SHFD AS LRAF 
							WHERE LRAF.ScheduleCode = @sScheduleCode AND LRAF.Rate >= @ApplicableMinimumNoteRate
							GROUP BY LRAF.Fee, LRAF.Rate 
							ORDER BY LRAF.Rate ASC
						END
						ELSE
						BEGIN
						--[IBP] :: TFS:3564 : Added MinimumNoteRate criteria for Fee Selection 
							SELECT TOP 1 @lowestPricing = LRAF.Fee, @lowestNoterate = LRAF.Rate FROM UV_LoanRatesAgentFees_NoSHFD AS LRAF 
							WHERE LRAF.ScheduleCode = @sScheduleCode AND LRAF.Rate >= @ApplicableMinimumNoteRate
							GROUP BY LRAF.Fee, LRAF.Rate 
							ORDER BY LRAF.Rate ASC
						END
												
						   ---TFS ID 3242-Modified RateFee by including PricingAdjFee- Suvarna Aigal 02/Dec/20101 
						   --[IBPP3] :: [TFS] : 3626 :: Applied PFIPricing Adjustment Factor      
							 SET @lowestPricing = @lowestPricing +@MPFBankPricngAdjustmentFactor +@PFIBankPricingAdjustmentFactor    
						
						IF @SHFDType = 'Y' OR @SHFDType = 'y'
						BEGIN
						--[IBP] :: TFS:3564 : Added MaximumNoteRate criteria for Fee Selection 
							SELECT TOP 1 @highestPricing = LRAF.Fee, @highestNoteRate = LRAF.Rate FROM UV_LoanRatesAgentFees_SHFD AS LRAF 
							WHERE LRAF.ScheduleCode = @sScheduleCode AND LRAF.Rate <= @ApplicableMaximumNoteRate
							GROUP BY LRAF.Fee, LRAF.Rate 
							ORDER BY LRAF.Rate DESC
						END
						ELSE
						BEGIN
						--[IBP] :: TFS:3564 : Added MaximumNoteRate criteria for Fee Selection 
							SELECT TOP 1 @highestPricing = LRAF.Fee, @highestNoteRate = LRAF.Rate FROM UV_LoanRatesAgentFees_NoSHFD AS LRAF 
							WHERE LRAF.ScheduleCode = @sScheduleCode AND LRAF.Rate <= @ApplicableMaximumNoteRate
							GROUP BY LRAF.Fee, LRAF.Rate 
							ORDER BY LRAF.Rate DESC
						END
					END
				END
				
			 ---TFS ID 3242-Modified RateFee by including PricingAdjFee- Suvarna Aigal 02/Dec/20101   
			 --[IBPP3] :: [TFS] : 3626 :: Applied PFIPricing Adjustment Factor
				SET @highestPricing = @highestPricing +@MPFBankPricngAdjustmentFactor +@PFIBankPricingAdjustmentFactor  
				------------------------------------------------- 
									
									
									--Once get the Schedule code, get the DC interest rate
									If (@sDCRate=0)
										Begin
											Set @fDCRate=@sAFee
										End
									Else
										Begin
											Set @fDCRate=@sDCRate
										End 
									
									IF @sCurrentPricing IS NULL
									BEGIN
										Set @sAFDifference = (0 - (@fDCRate/100))*100
									END
									ELSE
									BEGIN
										Set @sAFDifference = (@sCurrentPricing - (@fDCRate/100))*100
									END
									
									------
									If convert(money,@sDeliveryAmount)> CONVERT(money,@sOriginalDCAmount)
										Begin
											Set @sReductionAmount=((@sDeliveryAmount-@sOriginalDCAmount)-@DCTolerance)* -1
											Set @sBalanceAtExpiration=CONVERT(money,CONVERT(money,(@sOriginalDCAmount + @DCTolerance)-@sFundedAmount))
										End
															
									--Get pair of fee calc
									Set @sPairOffFee=0
									Declare @sFee as decimal(30,8)
									--[IBP] :: TFS:3564 : Remove the �ReductionAmount > 0� check so that Fee is common for case when Delivery Commitment is overfunded or not. 
									--if (@sReductionAmount)>0
										--Begin
											Set @sFee=(@sReductionAmount * (@sAFDifference/100))
											
											If @sFee < 0
												Begin
													Set @sPairOffFee=0
												End
											Else
												Begin
													Set @sPairOffFee=CONVERT(Decimal(30,2),@sFee)
													
												End	
										--End							
				

							
						
					 Select @sProductCode as ProductCode,
						 @sNoteRate as NoteRate,
						 @sDeliveryDate As DeliveryDate,
						 @sScheduleCode as ScheduleCode,
						 @sAFee as AFee,
						 @sCurrentRate as CurrentRate,
						 @sDeliveryAmount as DeliveryAmount,
						 @sDCAmount as DCAmount,
						 @sFundedAmount as FundedAmount,
						 @DeliveryStatus as DeliveryStatus,
						 @sScheduleType as ScheduleType,
						 @sRemittanceTypeID as RemittanceTypeId,
						 @sTolerancePercent as TolerancePercent,
						 @sToleranceAmount as ToleranceAmount,
						 @sOriginalDCAmount as OriginalDCAmount,
						 @DCTolerance as DCTolerance,
						 @sAFDifference as AFDifference,
						 @sBalanceAtExpiration as BalanceAtExpiration,
						 @dblDaysForward as DaysForward,
						 @sManualReductions as ManualReduction,
						 @sExpiredReductions as ExpiredReduction,
						 @sRemittanceTypeDescription as RemittanceTypeDescription,
						 @boxReductionsDone as ReductionDone,
						 @boxDaysToExpiration as DaysToExpiration,
						 @sDCInterestNote as DCInterestNote,@ScheduleToUse as ScheduleToUse,
						 @sPairOffFee as PairOffFee,@DCMessage as DCMessage,@fDCRate as DCRate, @lowestNoterate as LowestNoteRate,
						 @lowestPricing as LowestPricing, @highestNoteRate as HighestNoteRate, @highestPricing as HighestPricing,
						 @sCurrentPricing as CurrentPricing, @CurrentDCRate as CUrrentDCRate
			
END



PRINT 'End 01_SSRS0300_Stored_Procedures_Alter.sql'


GO
