/**
 * @file
 * Implements ATR strategy based on the Average True Range indicator.
 */

// User input params.
INPUT_GROUP("ATR strategy: strategy params");
INPUT float ATR_LotSize = 0;                // Lot size
INPUT int ATR_SignalOpenMethod = 2;         // Signal open method (-127-127)
INPUT float ATR_SignalOpenLevel = 0.0f;     // Signal open level
INPUT int ATR_SignalOpenFilterMethod = 32;  // Signal open filter method
INPUT int ATR_SignalOpenFilterTime = 3;     // Signal open filter time
INPUT int ATR_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int ATR_SignalCloseMethod = 2;        // Signal close method (-127-127)
INPUT int ATR_SignalCloseFilter = 0;        // Signal close filter (-127-127)
INPUT float ATR_SignalCloseLevel = 0.0f;    // Signal close level
INPUT int ATR_PriceStopMethod = 1;          // Price stop method (0-127)
INPUT float ATR_PriceStopLevel = 2;         // Price stop level
INPUT int ATR_TickFilterMethod = 32;        // Tick filter method
INPUT float ATR_MaxSpread = 4.0;            // Max spread to trade (pips)
INPUT short ATR_Shift = 0;                  // Shift (relative to the current bar, 0 - default)
INPUT float ATR_OrderCloseLoss = 80;        // Order close loss
INPUT float ATR_OrderCloseProfit = 80;      // Order close profit
INPUT int ATR_OrderCloseTime = -30;         // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("ATR strategy: ATR indicator params");
INPUT int ATR_Indi_ATR_Period = 13;  // Period
INPUT int ATR_Indi_ATR_Shift = 0;    // Shift

// Structs.
// Defines struct with default user strategy values.
struct Stg_ATR_Params_Defaults : StgParams {
  Stg_ATR_Params_Defaults()
      : StgParams(::ATR_SignalOpenMethod, ::ATR_SignalOpenFilterMethod, ::ATR_SignalOpenLevel,
                  ::ATR_SignalOpenBoostMethod, ::ATR_SignalCloseMethod, ::ATR_SignalCloseFilter, ::ATR_SignalCloseLevel,
                  ::ATR_PriceStopMethod, ::ATR_PriceStopLevel, ::ATR_TickFilterMethod, ::ATR_MaxSpread, ::ATR_Shift) {
    Set(STRAT_PARAM_LS, ATR_LotSize);
    Set(STRAT_PARAM_OCL, ATR_OrderCloseLoss);
    Set(STRAT_PARAM_OCP, ATR_OrderCloseProfit);
    Set(STRAT_PARAM_OCT, ATR_OrderCloseTime);
    Set(STRAT_PARAM_SOFT, ATR_SignalOpenFilterTime);
  }
};

#ifdef __config__
// Loads pair specific param values.
#include "config/H1.h"
#include "config/H4.h"
#include "config/H8.h"
#include "config/M1.h"
#include "config/M15.h"
#include "config/M30.h"
#include "config/M5.h"
#endif

class Stg_ATR : public Strategy {
 public:
  Stg_ATR(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_ATR *Init(ENUM_TIMEFRAMES _tf = NULL) {
    // Initialize strategy initial values.
    Stg_ATR_Params_Defaults stg_atr_defaults;
    StgParams _stg_params(stg_atr_defaults);
#ifdef __config__
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_atr_m1, stg_atr_m5, stg_atr_m15, stg_atr_m30, stg_atr_h1, stg_atr_h4,
                             stg_atr_h8);
#endif
    // Initialize indicator.
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams;
    Strategy *_strat = new Stg_ATR(_stg_params, _tparams, _cparams, "ATR");
    return _strat;
  }

  /**
   * Event on strategy's init.
   */
  void OnInit() {
    IndiATRParams _indi_params(::ATR_Indi_ATR_Period, ::ATR_Indi_ATR_Shift);
    _indi_params.SetTf(Get<ENUM_TIMEFRAMES>(STRAT_PARAM_TF));
    SetIndicator(new Indi_ATR(_indi_params));
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_ATR *_indi = GetIndicator();
    bool _result = _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID, _shift);
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    IndicatorSignal _signals = _indi.GetSignals(4, _shift);
    switch (_cmd) {
      // Note: ATR doesn't give independent signals. Is used to define volatility (trend strength).
      // Principle: trend must be strengthened. Together with that ATR grows.
      case ORDER_TYPE_BUY:
        // Buy: if the indicator is increasing and above zero.
        // Buy: if the indicator values are increasing.
        _result &= _indi[CURR][0] > 0 && _indi.IsIncreasing(2);
        _result &= _indi.IsIncByPct(_level, 0, 0, 3);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        // @todo: Signal: Changing from negative values to positive.
        break;
      case ORDER_TYPE_SELL:
        // Sell: if the indicator is decreasing and below zero and a column is red.
        _result &= _indi[CURR][0] < 0 && _indi.IsDecreasing(2);
        _result &= _indi.IsDecByPct(-_level, 0, 0, 3);
        _result &= _method > 0 ? _signals.CheckSignals(_method) : _signals.CheckSignalsAll(-_method);
        // @todo: Signal: Changing from positive values to negative.
        break;
    }
    return _result;
  }
};
