package app.geocent

import app.geocent.ui.theme.Accent
import app.geocent.ui.theme.DarkColors
import app.geocent.ui.theme.LightColors
import org.junit.Assert.assertEquals
import org.junit.Test

class ThemeTokensTest {
    @Test
    fun accentIsSharedAcrossModes() {
        assertEquals(Accent, LightColors.accent)
        assertEquals(Accent, DarkColors.accent)
    }
}
