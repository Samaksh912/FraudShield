from app.utils.math_utils import clamped_ratio, zscore, EPSILON


def test_clamped_ratio_normal():
    assert clamped_ratio(50.0, 100.0, cap=1.0) == 0.5


def test_clamped_ratio_zero_denominator():
    result = clamped_ratio(50.0, 0.0, cap=1.0)
    assert result == 1.0  # 50 / EPSILON >> 1.0, capped


def test_clamped_ratio_exceeds_cap():
    assert clamped_ratio(200.0, 100.0, cap=1.0) == 1.0


def test_clamped_ratio_cap_5():
    assert clamped_ratio(600.0, 100.0, cap=5.0) == 5.0


def test_zscore_normal():
    result = zscore(10.0, [5.0, 7.0, 9.0, 11.0, 13.0])
    assert isinstance(result, float)
    assert abs(result) < 3.0


def test_zscore_insufficient_history():
    assert zscore(10.0, [5.0]) == 0.0


def test_zscore_zero_std():
    assert zscore(10.0, [10.0, 10.0, 10.0]) == 0.0


def test_zscore_negative():
    result = zscore(1.0, [5.0, 7.0, 9.0, 11.0])
    assert result < 0.0
