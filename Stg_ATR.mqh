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
INPUT int ATR_SignalOpenBoostMethod = 0;    // Signal open boost method
INPUT int ATR_SignalCloseMethod = 2;        // Signal close method (-127-127)
INPUT float ATR_SignalCloseLevel = 0.0f;    // Signal close level
INPUT int ATR_PriceStopMethod = 1;          // Price stop method
INPUT float ATR_PriceStopLevel = 2;         // Price stop level
INPUT int ATR_TickFilterMethod = 32;        // Tick filter method
INPUT float ATR_MaxSpread = 4.0;            // Max spread to trade (pips)
INPUT short ATR_Shift = 0;                  // Shift (relative to the current bar, 0 - default)
INPUT int ATR_OrderCloseTime = -20;         // Order close time in mins (>0) or bars (<0)
INPUT_GROUP("ATR strategy: ATR indicator params");
INPUT int ATR_Indi_ATR_Period = 14;  // Period
INPUT int ATR_Indi_ATR_Shift = 0;    // Shift

// Structs.

// Defines struct with default user indicator values.
struct Indi_ATR_Params_Defaults : ATRParams {
  Indi_ATR_Params_Defaults() : ATRParams(::ATR_Indi_ATR_Period, ::ATR_Indi_ATR_Shift) {}
} indi_atr_defaults;

// Defines struct with default user strategy values.
struct Stg_ATR_Params_Defaults : StgParams {
  Stg_ATR_Params_Defaults()
      : StgParams(::ATR_SignalOpenMethod, ::ATR_SignalOpenFilterMethod, ::ATR_SignalOpenLevel,
                  ::ATR_SignalOpenBoostMethod, ::ATR_SignalCloseMethod, ::ATR_SignalCloseLevel, ::ATR_PriceStopMethod,
                  ::ATR_PriceStopLevel, ::ATR_TickFilterMethod, ::ATR_MaxSpread, ::ATR_Shift, ::ATR_OrderCloseTime) {}
} stg_atr_defaults;

// Struct to define strategy parameters to override.
struct Stg_ATR_Params : StgParams {
  ATRParams iparams;
  StgParams sparams;

  // Struct constructors.
  Stg_ATR_Params(ATRParams &_iparams, StgParams &_sparams)
      : iparams(indi_atr_defaults, _iparams.tf.GetTf()), sparams(stg_atr_defaults) {
    iparams = _iparams;
    sparams = _sparams;
  }
};

// Loads pair specific param values.
#include "config/H1.h"
#include "config/H4.h"
#include "config/H8.h"
#include "config/M1.h"
#include "config/M15.h"
#include "config/M30.h"
#include "config/M5.h"

class Stg_ATR : public Strategy {
 public:
  Stg_ATR(StgParams &_sparams, TradeParams &_tparams, ChartParams &_cparams, string _name = "")
      : Strategy(_sparams, _tparams, _cparams, _name) {}

  static Stg_ATR *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    ATRParams _indi_params(indi_atr_defaults, _tf);
    StgParams _stg_params(stg_atr_defaults);
#ifdef __config__
    SetParamsByTf<ATRParams>(_indi_params, _tf, indi_atr_m1, indi_atr_m5, indi_atr_m15, indi_atr_m30, indi_atr_h1,
                             indi_atr_h4, indi_atr_h8);
    SetParamsByTf<StgParams>(_stg_params, _tf, stg_atr_m1, stg_atr_m5, stg_atr_m15, stg_atr_m30, stg_atr_h1, stg_atr_h4,
                             stg_atr_h8);
#endif
    // Initialize indicator.
    ATRParams atr_params(_indi_params);
    _stg_params.SetIndicator(new Indi_ATR(_indi_params));
    // Initialize Strategy instance.
    ChartParams _cparams(_tf, _Symbol);
    TradeParams _tparams(_magic_no, _log_level);
    Strategy *_strat = new Stg_ATR(_stg_params, _tparams, _cparams, "ATR");
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_ATR *_indi = GetIndicator();
    bool _result = _indi.GetFlag(INDI_ENTRY_FLAG_IS_VALID);
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
