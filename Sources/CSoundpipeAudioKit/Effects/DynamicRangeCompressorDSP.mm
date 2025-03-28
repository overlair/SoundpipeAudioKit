// Copyright AudioKit. All Rights Reserved.

#include "SoundpipeDSPBase.h"
#include "ParameterRamper.h"
#include "Soundpipe.h"

enum DynamicRangeCompressorParameter : AUParameterAddress {
    DynamicRangeCompressorParameterRatio,
    DynamicRangeCompressorParameterThreshold,
    DynamicRangeCompressorParameterAttackDuration,
    DynamicRangeCompressorParameterReleaseDuration,
    DynamicRangeCompressorParameterGain,
    DynamicRangeCompressorParameterDryWetMix,
};

class DynamicRangeCompressorDSP : public SoundpipeDSPBase {
private:
    sp_compressor *compressor0;
    sp_compressor *compressor1;
    ParameterRamper ratioRamp;
    ParameterRamper thresholdRamp;
    ParameterRamper attackDurationRamp;
    ParameterRamper releaseDurationRamp;
    ParameterRamper gainRamp;
    ParameterRamper dryWetMixRamp;

public:
    DynamicRangeCompressorDSP() {
        parameters[DynamicRangeCompressorParameterRatio] = &ratioRamp;
        parameters[DynamicRangeCompressorParameterThreshold] = &thresholdRamp;
        parameters[DynamicRangeCompressorParameterAttackDuration] = &attackDurationRamp;
        parameters[DynamicRangeCompressorParameterReleaseDuration] = &releaseDurationRamp;
        parameters[DynamicRangeCompressorParameterGain] = &gainRamp;
        parameters[DynamicRangeCompressorParameterDryWetMix] = &dryWetMixRamp;
    }

    void init(int channelCount, double sampleRate) override {
        SoundpipeDSPBase::init(channelCount, sampleRate);
        sp_compressor_create(&compressor0);
        sp_compressor_init(sp, compressor0);
        sp_compressor_create(&compressor1);
        sp_compressor_init(sp, compressor1);
    }

    void deinit() override {
        SoundpipeDSPBase::deinit();
        sp_compressor_destroy(&compressor0);
        sp_compressor_destroy(&compressor1);
    }

    void reset() override {
        SoundpipeDSPBase::reset();
        if (!isInitialized) return;
        sp_compressor_init(sp, compressor0);
        sp_compressor_init(sp, compressor1);
    }

    void process(FrameRange range) override {
        for (int i : range) {
            *compressor0->ratio = *compressor1->ratio = ratioRamp.getAndStep();
            *compressor0->thresh = *compressor1->thresh = thresholdRamp.getAndStep();
            *compressor0->atk = *compressor1->atk = attackDurationRamp.getAndStep();
            *compressor0->rel = *compressor1->rel = releaseDurationRamp.getAndStep();

            float leftIn = inputSample(0, i);
            float rightIn = inputSample(1, i);

            float &leftOut = outputSample(0, i);
            float &rightOut = outputSample(1, i);

            sp_compressor_compute(sp, compressor0, &leftIn, &leftOut);
            sp_compressor_compute(sp, compressor1, &rightIn, &rightOut);

            float gain = gainRamp.getAndStep();
            leftOut *= gain;
            rightOut *= gain;

            float dryWetMix = dryWetMixRamp.getAndStep();
            outputSample(0, i) = dryWetMix * leftOut + (1.0f - dryWetMix) * leftIn;
            outputSample(1, i) = dryWetMix * rightOut + (1.0f - dryWetMix) * rightIn;
        }
    }
};

AK_REGISTER_DSP(DynamicRangeCompressorDSP, "cpsr")
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterRatio)
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterThreshold)
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterAttackDuration)
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterReleaseDuration)
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterGain)
AK_REGISTER_PARAMETER(DynamicRangeCompressorParameterDryWetMix)
