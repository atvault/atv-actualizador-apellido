@IsTest
private class ATV_AOC_DTO_Test {
	@IsTest static void instantiateDto() {
		ATV_AOC_DTO dto = new ATV_AOC_DTO();
		dto.accountId = '001000000000000AAA';
		dto.aocId = 'a0A000000000000AAA';
		dto.contactoPrincipalId = '003000000000000AAA';
		dto.competencia = 'OTRO';
		dto.puntoDeDolor = 'PRECIO;CALIDAD';
		System.assertEquals('OTRO', dto.competencia);
	}
}