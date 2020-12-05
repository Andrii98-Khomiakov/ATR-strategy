/**
 * @file
 * Implements ATR strategy based on the Average True Range indicator.
 */

// Includes.
#include <EA31337-classes/Indicators/Indi_ATR.mqh>
#include <EA31337-classes/Strategy.mqh>

// User input params.
INPUT float ATR_LotSize = 0;               // Lot size
INPUT int ATR_SignalOpenMethod = 0;        // Signal open method (0-31)
INPUT float ATR_SignalOpenLevel = 0;       // Signal open level
INPUT int ATR_SignalOpenFilterMethod = 0;  // Signal open filter method
INPUT int ATR_SignalOpenBoostMethod = 0;   // Signal open boost method
INPUT int ATR_SignalCloseMethod = 0;       // Signal close method
INPUT float ATR_SignalCloseLevel = 0;      // Signal close level
INPUT int ATR_PriceStopMethod = 0;         // Price stop method
INPUT float ATR_PriceStopLevel = 2;        // Price stop level
INPUT int ATR_TickFilterMethod = 0;        // Tick filter method
INPUT float ATR_MaxSpread = 6.0;           // Max spread to trade (pips)
INPUT int ATR_Shift = 0;                   // Shift (relative to the current bar, 0 - default)
INPUT string __ATR_Indi_ATR_Parameters__ =
    "-- ATR strategy: ATR indicator params --";  // >>> ATR strategy: ATR indicator <<<
INPUT int Indi_ATR_Period = 14;                  // Period

// Structs.

// Defines struct with default user indicator values.
struct Indi_ATR_Params_Defaults : ATRParams {
  Indi_ATR_Params_Defaults() : ATRParams(::Indi_ATR_Period) {}
} indi_atr_defaults;

// Defines struct to store indicator parameter values.
struct Indi_ATR_Params : public ATRParams {
  // Struct constructors.
  void Indi_ATR_Params(ATRParams &_params, ENUM_TIMEFRAMES _tf) : ATRParams(_params, _tf) {}
};

// Defines struct with default user strategy values.
struct Stg_ATR_Params_Defaults : StgParams {
  Stg_ATR_Params_Defaults()
      : StgParams(::ATR_SignalOpenMethod, ::ATR_SignalOpenFilterMethod, ::ATR_SignalOpenLevel,
                  ::ATR_SignalOpenBoostMethod, ::ATR_SignalCloseMethod, ::ATR_SignalCloseLevel, ::ATR_PriceStopMethod,
                  ::ATR_PriceStopLevel, ::ATR_TickFilterMethod, ::ATR_MaxSpread, ::ATR_Shift) {}
} stg_atr_defaults;

// Struct to define strategy parameters to override.
struct Stg_ATR_Params : StgParams {
  Indi_ATR_Params iparams;
  StgParams sparams;

  // Struct constructors.
  Stg_ATR_Params(Indi_ATR_Params &_iparams, StgParams &_sparams)
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
    Indi_ATR_Params _indi_params(indi_atr_defaults, _tf);
    StgParams _stg_params(stg_atr_defaults);
    if (!Terminal::IsOptimization()) {
      SetParamsByTf<Indi_ATR_Params>(_indi_params, _tf, indi_atr_m1, indi_atr_m5, indi_atr_m15, indi_atr_m30,
                                     indi_atr_h1, indi_atr_h4, indi_atr_h8);
      SetParamsByTf<StgParams>(_stg_params, _tf, stg_atr_m1, stg_atr_m5, stg_atr_m15, stg_atr_m30, stg_atr_h1,
                               stg_atr_h4, stg_atr_h8);
    }
    // Initialize indicator.
    ATRParams atr_params(_indi_params);
    _stg_params.SetIndicator(new Indi_ATR(_indi_params));
    // Initialize strategy parameters.
    _stg_params.GetLog().SetLevel(_log_level);
    _stg_params.SetMagicNo(_magic_no);
    _stg_params.SetTf(_tf, _Symbol);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_ATR(_stg_params, "ATR");
    _stg_params.SetStops(_strat, _strat);
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, float _level = 0.0f, int _shift = 0) {
    Indi_ATR *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid();
    bool _result = _is_valid;
    switch (_cmd) {
      // Note: ATR doesn't give independent signals. Is used to define volatility (trend strength).
      // Principle: trend must be strengthened. Together with that ATR grows.
      case ORDER_TYPE_BUY:
        _result &= _indi[CURR][0] + _level >= _indi[PREV][0];
        if (METHOD(_method, 0)) _result &= _indi[PPREV][0] + _level >= _indi[PREV][0];
        break;
      case ORDER_TYPE_SELL:
        _result &= _indi[CURR][0] + _level <= _indi[PREV][0];
        if (METHOD(_method, 0)) _result &= _indi[PPREV][0] + _level <= _indi[PREV][0];
        break;
    }
    return _result;
  }

  /**
   * Gets price stop value for profit take or stop loss.
   */
  float PriceStop(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, float _level = 0.0) {
    Indi_ATR *_indi = Data();
    double _trail = _level * Market().GetPipSize();
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    switch (_method) {
      case 1: {
        int _bar_count = (int)_level * (int)_indi.GetPeriod();
        _result = _direction > 0 ? _indi.GetPrice(PRICE_HIGH, _indi.GetHighest(_bar_count))
                                 : _indi.GetPrice(PRICE_LOW, _indi.GetLowest(_bar_count));
        break;
      }
    }
    return (float)_result;
  }
};
