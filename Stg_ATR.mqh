/**
 * @file
 * Implements ATR strategy based on the Average True Range indicator.
 */

// User input params.
INPUT string __ATR_Parameters__ = "-- ATR strategy params --";  // >>> ATR <<<
INPUT float ATR_LotSize = 0;                                    // Lot size
INPUT int ATR_SignalOpenMethod = 0;                             // Signal open method (0-31)
INPUT float ATR_SignalOpenLevel = 0.0f;                         // Signal open level
INPUT int ATR_SignalOpenFilterMethod = 1;                       // Signal open filter method
INPUT int ATR_SignalOpenBoostMethod = 0;                        // Signal open boost method
INPUT int ATR_SignalCloseMethod = 0;                            // Signal close method
INPUT float ATR_SignalCloseLevel = 0.0f;                        // Signal close level
INPUT int ATR_PriceStopMethod = 0;                              // Price stop method
INPUT float ATR_PriceStopLevel = 2;                             // Price stop level
INPUT int ATR_TickFilterMethod = 1;                             // Tick filter method
INPUT float ATR_MaxSpread = 4.0;                                // Max spread to trade (pips)
INPUT short ATR_Shift = 0;                                      // Shift (relative to the current bar, 0 - default)
INPUT int ATR_OrderCloseTime = -20;                             // Order close time in mins (>0) or bars (<0)
INPUT string __ATR_Indi_ATR_Parameters__ =
    "-- ATR strategy: ATR indicator params --";  // >>> ATR strategy: ATR indicator <<<
INPUT int ATR_Indi_ATR_Period = 14;              // Period
INPUT int ATR_Indi_ATR_Shift = 0;                // Shift

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
      : iparams(indi_atr_defaults, _iparams.tf), sparams(stg_atr_defaults) {
    iparams = _iparams;
    sparams = _sparams;
  }
};

// Loads pair specific param values.
#include "config/EURUSD_H1.h"
#include "config/EURUSD_H4.h"
#include "config/EURUSD_H8.h"
#include "config/EURUSD_M1.h"
#include "config/EURUSD_M15.h"
#include "config/EURUSD_M30.h"
#include "config/EURUSD_M5.h"

class Stg_ATR : public Strategy {
 public:
  Stg_ATR(StgParams &_params, string _name) : Strategy(_params, _name) {}

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
    // Initialize strategy parameters.
    _stg_params.GetLog().SetLevel(_log_level);
    _stg_params.SetMagicNo(_magic_no);
    _stg_params.SetTf(_tf, _Symbol);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_ATR(_stg_params, "ATR");
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_ATR *_indi = GetIndicator();
    bool _is_valid = _indi[CURR].IsValid();
    bool _result = _is_valid;
    if (_is_valid) {
      switch (_cmd) {
        // Note: ATR doesn't give independent signals. Is used to define volatility (trend strength).
        // Principle: trend must be strengthened. Together with that ATR grows.
        case ORDER_TYPE_BUY:
          // Buy: if the indicator is increasing and above zero.
          _result &= _indi[CURR][0] > 0 && _indi.IsIncreasing(3);
          _result &= _indi.IsIncByPct(_level, 0, 0, 2);
          if (_result && _method != 0) {
            if (METHOD(_method, 0)) _result &= _indi.IsIncreasing(2, 0, 3);
            if (METHOD(_method, 1)) _result &= _indi.IsIncreasing(2, 0, 5);
            // Signal: Changing from negative values to positive.
            if (METHOD(_method, 2)) _result &= _indi[PPREV][0] < 0;
          }
          break;
        case ORDER_TYPE_SELL:
          // Sell: if the indicator is decreasing and below zero and a column is red.
          _result &= _indi[CURR][0] < 0 && _indi.IsDecreasing(3);
          _result &= _indi.IsDecByPct(-_level, 0, 0, 2);
          if (_result && _method != 0) {
            if (METHOD(_method, 0)) _result &= _indi.IsDecreasing(2, 0, 3);
            if (METHOD(_method, 1)) _result &= _indi.IsDecreasing(2, 0, 5);
            // Signal: Changing from positive values to negative.
            if (METHOD(_method, 2)) _result &= _indi[PPREV][0] > 0;
          }
          break;
      }
    }
    return _result;
  }

  /**
   * Gets price stop value for profit take or stop loss.
   */
  float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0f) {
    Indicator *_indi = GetIndicator();
    Chart *_chart = sparams.GetChart();
    double _trail = _level * _chart.GetPipSize();
    int _bar_count = (int)_level * 10;
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _change_pc = Math::ChangeInPct(_indi[1][0], _indi[0][0]);
    double _default_value = _chart.GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _price_offer = _chart.GetOpenOffer(_cmd);
    double _result = _default_value;
    ENUM_APPLIED_PRICE _ap = _direction > 0 ? PRICE_HIGH : PRICE_LOW;
    switch (_method) {
      case 1:
        _result = _indi.GetPrice(
            _ap, _direction > 0 ? _indi.GetHighest<double>(_bar_count) : _indi.GetLowest<double>(_bar_count));
        break;
      case 2:
        _result = Math::ChangeByPct(_price_offer, (float)(_change_pc / 100 * Math::NonZero(_level)));
        break;
    }
    return (float)_result;
  }
};
