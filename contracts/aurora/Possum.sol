/* // SPDX-License-Identifier: MIT
/**
 * Created on 2021-12-01
 */
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2; 

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./interfaces/IAdminTools.sol";
import "./interfaces/ITrancheTokens.sol";
import "./interfaces/ITranchesDeployer.sol";
import "./PossumStorage.sol";
import "./interfaces/IPossum.sol";
import "./interfaces/IToken.sol";

contract Possum is OwnableUpgradeable, ReentrancyGuardUpgradeable, PossumStorage, IPossum {
    using SafeMathUpgradeable for uint256;

    function initialize(address _adminTools,
            address _feesCollector,
            address _tranchesDepl) external initializer() {
        OwnableUpgradeable.__Ownable_init();
        adminToolsAddress = _adminTools;
        feesCollectorAddress = _feesCollector;
        tranchesDeployerAddress = _tranchesDepl;
    }

    modifier onlyAdmins() {
        require(IAdminTools(adminToolsAddress).isAdmin(msg.sender), "not an Admin");
        _;
    }

    fallback() external payable {
        revert('not allowed');
    }
    receive() external payable {
        revert('not allowed');
    }
  
    /*
     * @dev add new tranche to protocol
     * @param xxx
     */

    function addTrancheToProtocol(address _buyerCoinAddress,
            address _yTokenAddress,
            string memory _nameA,
            string memory _symbolA,
            string memory _nameB,
            string memory _symbolB,
            uint256[7] memory _params,
            uint8 _underlyingDec) external onlyAdmins nonReentrant {
        require(tranchesDeployerAddress != address(0), "set deployer");

        trancheAddresses[tranchePairsCounter].buyerCoinAddress = _buyerCoinAddress;
        trancheAddresses[tranchePairsCounter].yTokenAddress = _yTokenAddress;
        trancheAddresses[tranchePairsCounter].ATrancheAddress =
                ITranchesDeployer(tranchesDeployerAddress).deployNewTrancheATokens(_nameA, _symbolA, tranchePairsCounter);
        trancheAddresses[tranchePairsCounter].BTrancheAddress =
                ITranchesDeployer(tranchesDeployerAddress).deployNewTrancheBTokens(_nameB, _symbolB, tranchePairsCounter);
        trancheParameters[tranchePairsCounter].underlyingDecimals = _underlyingDec;

        trancheRunningParams[tranchePairsCounter].trancheInitTime = block.timestamp;
        trancheRunningParams[tranchePairsCounter].canRedeem = false;
        trancheRunningParams[tranchePairsCounter].redemptionPercentage = 10000;  //default value 100%, no fees

        trancheParameters[tranchePairsCounter].RISK = _params[0];
        trancheParameters[tranchePairsCounter].minVaribleToken = _params[1];
        trancheParameters[tranchePairsCounter].maxVaribleToken = _params[2];
        trancheParameters[tranchePairsCounter].varibleTokenLimit = _params[3];
        trancheParameters[tranchePairsCounter].tranchBTimeout = _params[4];
        trancheParameters[tranchePairsCounter].gamePeriod = _params[5];
        trancheParameters[tranchePairsCounter].lockPeriod = _params[6];
        
        IAdminTools(adminToolsAddress).addAdmin(trancheAddresses[tranchePairsCounter].ATrancheAddress);
        IAdminTools(adminToolsAddress).addAdmin(trancheAddresses[tranchePairsCounter].BTrancheAddress);
        tranchePairsCounter = tranchePairsCounter.add(1);

        emit TrancheAddedToProtocol(tranchePairsCounter, trancheAddresses[tranchePairsCounter].ATrancheAddress, trancheAddresses[tranchePairsCounter].BTrancheAddress);

    }

    /*
     * @dev deposit to another protocol
     * @param _trNum  tranche index
     * @param _amount deposit amount
     */

    function underlyDeposit(uint256 _trNum, uint256 _amount) internal {
        address origToken = trancheAddresses[_trNum].buyerCoinAddress;
        address yToken = trancheAddresses[_trNum].yTokenAddress;
        require(_amount <= IERC20Upgradeable(origToken).balanceOf(msg.sender), "Insufficient Balance");
        uint256 yTokenBefore = getTokenBalance(yToken, address(this));
        IERC20Upgradeable(origToken).approve(yToken, _amount);

        IToken(yToken).deposit(_amount);
        uint256 yTokenAfter = getTokenBalance(yToken, address(this));
        if (yTokenAfter > yTokenBefore)
          trancheRunningParams[_trNum].TranchTotalYToken = trancheRunningParams[_trNum].TranchTotalYToken.add(yTokenAfter.sub(yTokenBefore));
        else
          trancheRunningParams[_trNum].TranchTotalYToken = trancheRunningParams[_trNum].TranchTotalYToken.add(0);
    }

    function underlyWithdraw(uint256 _trNum) internal returns (bool) {
        address yToken = trancheAddresses[_trNum].yTokenAddress;

        IToken(yToken).withdraw(trancheRunningParams[_trNum].TranchTotalYToken);
        trancheRunningParams[_trNum].TranchTotalYToken = 0;
      
        return true;
    }
    /*
     * @dev deposit to another protocol
     * @param _trNum  tranche index
     * @param _amount deposit amount
     */

    function setTrancheAExchangeRate(uint256 _trancheNum) internal returns (uint256) {
        //Calculate the price algorithmically

        return trancheParameters[_trancheNum].storedTrancheAPrice;
    }

    /*
     * @dev buy tranche A
     * @param _trNum  tranche index
     * @param _amount amount
     */
    function buyTrancheAToken(uint256 _trancheNum, uint256 _amount) external payable nonReentrant {
        
        require((block.timestamp > trancheRunningParams[_trancheNum].trancheInitTime.add(trancheParameters[_trancheNum].tranchBTimeout)) && (block.timestamp < (trancheRunningParams[_trancheNum].trancheInitTime.add(trancheParameters[_trancheNum].tranchBTimeout).add(trancheParameters[_trancheNum].gamePeriod))), "wrong time");
        uint256 totalAmout = IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).totalSupply().add(IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply());
        require(((IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply())).mul(1e4).div(totalAmout.add(_amount)) >= trancheParameters[_trancheNum].minVaribleToken, "exceed limit");
        address _tokenAddr = trancheAddresses[_trancheNum].buyerCoinAddress;
        require(IERC20Upgradeable(_tokenAddr).allowance(msg.sender, address(this)) >= _amount, "allowance failed");
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_tokenAddr), msg.sender, address(this), _amount);
        uint256 normAmount;
        uint256 diffDec = uint256(18).sub(uint256(trancheParameters[_trancheNum].underlyingDecimals));
        normAmount = _amount.mul(10 ** diffDec);
        ITrancheTokens(trancheAddresses[_trancheNum].ATrancheAddress).mint(msg.sender, normAmount);
        setTrancheAExchangeRate(_trancheNum);
        emit TrancheATokenMinted(_trancheNum, msg.sender, _amount, normAmount);
    }

    /*
     * @dev handle function
     * @param _trNum  tranche index
     */
    function handleTranche(uint256 _trancheNum) external onlyAdmins nonReentrant{
      require(block.timestamp > trancheRunningParams[_trancheNum].trancheInitTime.add(trancheParameters[_trancheNum].tranchBTimeout).add(trancheParameters[_trancheNum].gamePeriod), "wt");
      uint256 totalAmout = IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).totalSupply().add(IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply());
      if (((IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply()).div(totalAmout).mul(1e4)) <= trancheParameters[_trancheNum].maxVaribleToken)
      {
        underlyDeposit(_trancheNum, totalAmout);
      }
      else {
        trancheRunningParams[_trancheNum].canRedeem = true;
        trancheParameters[_trancheNum].storedTrancheAPrice = E;
        trancheParameters[_trancheNum].storedTrancheBPrice = E;
      }
    }

    /*
     * @dev stop function
     * @param _trNum  tranche index
     */
    function stopTranche(uint256 _trancheNum) external onlyAdmins nonReentrant{
      require(block.timestamp > trancheRunningParams[_trancheNum].trancheInitTime.add(trancheParameters[_trancheNum].tranchBTimeout).add(trancheParameters[_trancheNum].gamePeriod).add(trancheParameters[_trancheNum].lockPeriod), "wt");
      address origToken = trancheAddresses[_trancheNum].buyerCoinAddress;
      uint256 prevOrigTokenAmount = IERC20Upgradeable(origToken).balanceOf(address(this));
      underlyWithdraw(_trancheNum);
      if (IERC20Upgradeable(origToken).balanceOf(address(this)) >= prevOrigTokenAmount){
        trancheRunningParams[_trancheNum].TranchTotalOrigToken = IERC20Upgradeable(origToken).balanceOf(address(this)).sub(prevOrigTokenAmount);
        trancheParameters[_trancheNum].storedTrancheBPrice = ((IERC20Upgradeable(origToken).balanceOf(address(this)).sub(prevOrigTokenAmount)).mul(E).sub(trancheParameters[_trancheNum].storedTrancheAPrice.mul(IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).totalSupply()).mul(trancheParameters[_trancheNum].lockPeriod).div(SECONDS_PER_YEAR))).div(IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply());
      }
      else{
        trancheRunningParams[_trancheNum].TranchTotalOrigToken = 0;
      }
      trancheRunningParams[_trancheNum].canRedeem = true;
      emit StopTrancheSuccess(_trancheNum);
    }

    /*
     * @dev calculate user's earn when stop tranche
     * @param amount  user's voucher token amount
     * @param _trancheNum tranche index
     * @param type
     */
    function getFinalEarn(uint256 amount, uint256 _trancheNum, bool _isTrancheA) internal view returns (uint256){
        //Calculate the amount algorithmically

    }


    function getUserAmount(uint256 _trancheNum, uint256 _amount, bool _isTrancheA) internal view returns(uint256, uint256){
        if (trancheParameters[_trancheNum].underlyingDecimals < 18) {
          uint256 diffDec = uint256(18).sub(uint256(trancheParameters[_trancheNum].underlyingDecimals));
          _amount = _amount.div(10 ** diffDec);
        }

        _amount = getFinalEarn(_amount, _trancheNum, _isTrancheA);

        uint256 redemptionPercent = uint256(trancheRunningParams[_trancheNum].redemptionPercentage);
        uint256 userAmount = _amount.mul(redemptionPercent).div(PERCENT_DIVIDER);
        return (_amount, userAmount);
    }


    function redeemTrancheToken(uint256 _trancheNum) external nonReentrant {
        require(trancheRunningParams[_trancheNum].canRedeem, "wrong time");
        require(IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).allowance(msg.sender, address(this)) >= IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).balanceOf(msg.sender),
                "failed A");
        require(IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).allowance(msg.sender, address(this)) >= IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).balanceOf(msg.sender),
                "failed B");
        uint256 Aamount = IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress).balanceOf(msg.sender);
        if (Aamount != 0)
          SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(trancheAddresses[_trancheNum].ATrancheAddress), msg.sender, address(this), Aamount);

        uint256 Bamount = IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).balanceOf(msg.sender);
        if (Bamount != 0)
          SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress), msg.sender, address(this), Bamount);

        address origToken = trancheAddresses[_trancheNum].buyerCoinAddress;
        (uint256 Atamount, uint256 AuserAmount) = getUserAmount(_trancheNum, Aamount, true);
        (uint256 Btamount, uint256 BuserAmount) = getUserAmount(_trancheNum, Bamount, false);

        uint256 tamount = Atamount.add(Btamount);
        uint256 userAmount = AuserAmount.add(BuserAmount);

        uint256 tmpBal = Atamount.add(Btamount);

        if (tamount > 0 && trancheRunningParams[_trancheNum].TranchTotalOrigToken >= tamount) {
            if(userAmount <= tamount) {
                SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(origToken), msg.sender, userAmount);
                trancheRunningParams[_trancheNum].TranchTotalOrigToken = trancheRunningParams[_trancheNum].TranchTotalOrigToken.sub(userAmount);
                tmpBal = tmpBal.sub(userAmount);
            } else {
                SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(origToken), msg.sender, tamount);
                trancheRunningParams[_trancheNum].TranchTotalOrigToken = trancheRunningParams[_trancheNum].TranchTotalOrigToken.sub(tamount);
                tmpBal = 0;
            }
        }

        uint256 feesAmount = tamount.sub(userAmount);
        if (tmpBal > 0 && feesAmount > 0) {
            if (feesAmount <= tmpBal){
              SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(origToken), feesCollectorAddress, feesAmount);
              trancheRunningParams[_trancheNum].TranchTotalOrigToken = trancheRunningParams[_trancheNum].TranchTotalOrigToken.sub(feesAmount);
            }
            else
            {
              SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(origToken), feesCollectorAddress, tmpBal);
              trancheRunningParams[_trancheNum].TranchTotalOrigToken = trancheRunningParams[_trancheNum].TranchTotalOrigToken.sub(tmpBal);
            }
        }
        if (Aamount != 0)
          ITrancheTokens(trancheAddresses[_trancheNum].ATrancheAddress).burn(Aamount);

        if (Bamount != 0)
          ITrancheTokens(trancheAddresses[_trancheNum].BTrancheAddress).burn(Bamount);
        emit TrancheTokenRedemption(_trancheNum, msg.sender, userAmount, feesAmount); 
    }

    function buyTrancheBToken(uint256 _trancheNum, uint256 _amount) external payable nonReentrant {

        require((block.timestamp > trancheRunningParams[_trancheNum].trancheInitTime) && (block.timestamp < (trancheRunningParams[_trancheNum].trancheInitTime.add(trancheParameters[_trancheNum].tranchBTimeout))), "wrong time");
        require((IERC20Upgradeable(trancheAddresses[_trancheNum].BTrancheAddress).totalSupply().add(_amount)) < trancheParameters[_trancheNum].varibleTokenLimit, "exceed limit");

        uint256 diffDec = uint256(18).sub(uint256(trancheParameters[_trancheNum].underlyingDecimals));
        uint256 normAmount = _amount.mul(10 ** diffDec);

        address _tokenAddr = trancheAddresses[_trancheNum].buyerCoinAddress;
        require(IERC20Upgradeable(_tokenAddr).allowance(msg.sender, address(this)) >= _amount, "failed B");
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(_tokenAddr), msg.sender, address(this), _amount);
        
        ITrancheTokens(trancheAddresses[_trancheNum].BTrancheAddress).mint(msg.sender, normAmount);

        emit TrancheBTokenMinted(_trancheNum, msg.sender, _amount, normAmount);
    }

    function getTokenBalance(address _tokenContract, address _account) public view returns (uint256) {
        return IERC20Upgradeable(_tokenContract).balanceOf(_account);
    }

    function getTokenSupply(address _tokenContract) public view returns (uint256)  {
        return IERC20Upgradeable(_tokenContract).totalSupply();
    }
    function transferTokenToFeesCollector(address _tokenContract, uint256 _amount) external onlyAdmins {
        SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(_tokenContract), feesCollectorAddress, _amount);
    }

}
